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


import logging
logger = logging.getLogger(__name__)

async def handle_paddle_webhook(request: Request):
    """
    Processes incoming Paddle webhook events.
    """
    raw_body = await request.body()
    raw_body_str = raw_body.decode('utf-8')
    signature = request.headers.get('Paddle-Signature', '')
    
    # --- STEP 1: Validate HMAC signature ---
    if not verify_paddle_signature(raw_body_str, signature, os.environ['PADDLE_WEBHOOK_SECRET']):
        logger.warning(f"Invalid webhook signature received")
        raise HTTPException(status_code=400, detail='Invalid webhook signature')
    
    # --- STEP 2: Parse body only after validation ---
    try:
        payload = json.loads(raw_body_str)
    except Exception:
        logger.error("Failed to parse webhook JSON body")
        raise HTTPException(status_code=400, detail="Invalid JSON body")

    event_type = payload.get('event_type')
    logger.info(f"Received Paddle webhook event: {event_type}")
    
    if event_type == 'transaction.completed':
        data = payload.get('data', {})
        transaction_id = data.get('id')
        
        if not transaction_id:
            logger.error("Missing transaction_id in completed payload.")
            return {'status': 'ignored', 'reason': 'missing_transaction_id'}
            
        custom_data = data.get('custom_data', {})
        firebase_uid = custom_data.get('firebase_uid')
        
        if not firebase_uid:
            logger.warning(f'No firebase_uid in transaction {transaction_id}. Cannot upgrade user.')
            return {'status': 'ignored', 'reason': 'missing_uid'}
        
        upgraded = upgrade_user_to_pro(firebase_uid, transaction_id)
        status = 'upgraded' if upgraded else 'duplicate_ignored'
        logger.info(f'Webhook {transaction_id}: {status} for uid {firebase_uid}')
        return {'status': status}
    else:
        logger.info(f"Ignoring unhandled event type: {event_type}")
        return {'status': 'ignored', 'reason': 'unhandled_event_type'}
