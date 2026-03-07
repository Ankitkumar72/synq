from firebase_admin import firestore

db = firestore.client()


def upgrade_user_to_pro(firebase_uid: str, transaction_id: str) -> bool:
    """
    Idempotent upgrade: sets plan_tier to 'pro' in the user's Firestore document.
    
    Uses last_transaction_id to detect duplicate webhook deliveries.
    Returns True if upgraded, False if duplicate (already processed).
    """
    user_ref = db.collection('users').document(firebase_uid)
    
    # Check for duplicate webhook delivery
    doc = user_ref.get()
    if doc.exists:
        data = doc.to_dict()
        if data.get('last_transaction_id') == transaction_id:
            return False  # Already processed — safe to ignore
    
    # Merge upgrade data into existing document
    user_ref.set({
        'plan_tier': 'pro',
        'last_transaction_id': transaction_id,
        'upgraded_at': firestore.SERVER_TIMESTAMP,
    }, merge=True)
    
    return True
