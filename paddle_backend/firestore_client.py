from firebase_admin import firestore

db = firestore.client()


import logging

logger = logging.getLogger(__name__)

from google.cloud.firestore_v1.transaction import Transaction

@firestore.transactional
def _upgrade_transactional(transaction: Transaction, transaction_ref, user_ref, firebase_uid: str, transaction_id: str) -> bool:
    # Check for duplicate webhook delivery via transaction document, atomically
    doc = transaction_ref.get(transaction=transaction)
    if doc.exists:
        logger.info(f"Transaction {transaction_id} already processed. Ignoring.")
        return False
        
    # 1. Record transaction
    transaction.set(transaction_ref, {
        'user_id': firebase_uid,
        'processed_at': firestore.SERVER_TIMESTAMP,
        'status': 'completed'
    })
    
    # 2. Upgrade user
    transaction.set(user_ref, {
        'plan_tier': 'pro',
        'last_transaction_id': transaction_id,
        'upgraded_at': firestore.SERVER_TIMESTAMP,
    }, merge=True)
    
    return True

def upgrade_user_to_pro(firebase_uid: str, transaction_id: str) -> bool:
    """
    Idempotent upgrade: sets plan_tier to 'pro' in the user's Firestore document.
    Uses Firestore transaction to reliably and atomically detect duplicate webhook deliveries.
    Returns True if upgraded, False if duplicate (already processed).
    """
    transaction_ref = db.collection('paddle_transactions').document(transaction_id)
    user_ref = db.collection('users').document(firebase_uid)
    
    transaction = db.transaction()
    upgraded = _upgrade_transactional(transaction, transaction_ref, user_ref, firebase_uid, transaction_id)
    
    if upgraded:
        logger.info(f"Successfully upgraded user {firebase_uid} to pro via transaction {transaction_id}")
    return upgraded

def downgrade_user_to_free(firebase_uid: str) -> bool:
    """
    Sets plan_tier to 'free' in the user's Firestore document.
    Flags as over_limit if active_devices > 1.
    """
    user_ref = db.collection('users').document(firebase_uid)
    try:
        user_doc = user_ref.get()
        is_over_limit = False
        if user_doc.exists:
            user_data = user_doc.to_dict()
            active_devices = user_data.get('active_devices', [])
            if len(active_devices) > 1:
                is_over_limit = True

        user_ref.set({
            'plan_tier': 'free',
            'is_over_limit': is_over_limit,
            'downgraded_at': firestore.SERVER_TIMESTAMP,
        }, merge=True)
        logger.info(f"Successfully downgraded user {firebase_uid} to free (over_limit={is_over_limit})")
        return True
    except Exception as e:
        logger.error(f"Failed to downgrade user {firebase_uid}: {str(e)}")
        return False
