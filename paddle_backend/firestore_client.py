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
