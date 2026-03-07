import hmac
import hashlib
import json
import os

from fastapi import Request, HTTPException
from firestore_client import upgrade_user_to_pro


def verify_paddle_signature(raw_body: str, signature_header: str, secret_key: str) -> bool:
    """
    Validates the Paddle webhook signature using HMAC SHA256.
    
    Paddle signs with: ts=<timestamp>;h1=<hmac_hash>
    Payload to hash: "<timestamp>:<raw_body>"
    """
    try:
        parts = dict(part.split('=', 1) for part in signature_header.split(';'))
        ts = parts.get('ts', '')
        h1 = parts.get('h1', '')
        
        if not ts or not h1:
            return False
        
        payload = f"{ts}:{raw_body}".encode('utf-8')
        expected_hmac = hmac.new(
            secret_key.encode('utf-8'),
            msg=payload,
            digestmod=hashlib.sha256,
        ).hexdigest()
        
        return hmac.compare_digest(expected_hmac, h1)
    except Exception:
        return False


async def handle_paddle_webhook(request: Request):
    """
    Processes incoming Paddle webhook events.
    
    Security flow:
    1. Validate HMAC signature BEFORE parsing body
    2. Parse JSON only after validation passes
    3. Check idempotency on transaction_id
    4. Merge plan_tier: 'pro' into Firestore
    """
    raw_body = await request.body()
    raw_body_str = raw_body.decode('utf-8')
    signature = request.headers.get('Paddle-Signature', '')
    
    # --- STEP 1: Validate HMAC signature ---
    if not verify_paddle_signature(raw_body_str, signature, os.environ['PADDLE_WEBHOOK_SECRET']):
        raise HTTPException(status_code=400, detail='Invalid webhook signature')
    
    # --- STEP 2: Parse body only after validation ---
    payload = json.loads(raw_body_str)
    event_type = payload.get('event_type')
    
    if event_type == 'transaction.completed':
        data = payload['data']
        transaction_id = data['id']
        custom_data = data.get('custom_data', {})
        firebase_uid = custom_data.get('firebase_uid')
        
        if not firebase_uid:
            # Log warning but return 200 — don't trigger Paddle retries on bad data
            print(f'WARNING: No firebase_uid in transaction {transaction_id}')
            return {'status': 'ignored'}
        
        upgraded = upgrade_user_to_pro(firebase_uid, transaction_id)
        status = 'upgraded' if upgraded else 'duplicate_ignored'
        print(f'Webhook {transaction_id}: {status} for uid {firebase_uid}')
    
    # Always return 200 — Paddle retries on non-200 responses
    return {'status': 'ok'}
