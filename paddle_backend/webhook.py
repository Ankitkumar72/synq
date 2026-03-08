import hmac
import hashlib
import json
import os

import time
from fastapi import Request, HTTPException
from firestore_client import upgrade_user_to_pro, downgrade_user_to_free


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
            
        # --- Improvement 1: Timestamp Replay Protection ---
        try:
            timestamp = int(ts)
            current_time = int(time.time())
            if abs(current_time - timestamp) > 300:  # 5 minutes
                logger.warning(f"Webhook rejected: Timestamp too old ({ts})")
                return False
        except (ValueError, TypeError):
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
    
    # --- Improvement 3: Protect Against Missing Webhook Secret ---
    webhook_secret = os.environ.get('PADDLE_WEBHOOK_SECRET')
    if not webhook_secret:
        logger.error("PADDLE_WEBHOOK_SECRET not configured in environment")
        raise HTTPException(status_code=500, detail="Webhook secret not configured")

    # --- STEP 1: Validate HMAC signature ---
    if not verify_paddle_signature(raw_body_str, signature, webhook_secret):
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

    data = payload.get('data', {})
    
    # helper for UID extraction
    def get_firebase_uid(source_data):
        return source_data.get('custom_data', {}).get('firebase_uid')

    # --- HANDLE INITIAL PURCHASE ---
    if event_type == 'transaction.completed':
        transaction_id = data.get('id')
        if not transaction_id:
            logger.error("Missing transaction_id in completed payload.")
            return {'status': 'ignored', 'reason': 'missing_transaction_id'}

        # --- Improvement 2: Validate Product Price ---
        items = data.get("items", [])
        if not items:
            logger.warning(f"Transaction {transaction_id} has no items. Ignoring.")
            return {"status": "ignored", "reason": "missing_items"}

        price_id = items[0].get("price_id")
        expected_price_id = os.environ.get("PADDLE_PRICE_ID")

        if expected_price_id and price_id != expected_price_id:
            logger.warning(f"Unexpected price_id {price_id} for transaction {transaction_id}. Expected {expected_price_id}")
            return {"status": "ignored", "reason": "wrong_product"}
            
        firebase_uid = get_firebase_uid(data)
        if not firebase_uid:
            logger.warning(f'No firebase_uid in transaction {transaction_id}. Cannot upgrade user.')
            return {'status': 'ignored', 'reason': 'missing_uid'}
        
        upgraded = upgrade_user_to_pro(firebase_uid, transaction_id)
        status = 'upgraded' if upgraded else 'duplicate_ignored'
        logger.info(f'Webhook {transaction_id}: {status} for uid {firebase_uid}')
        return {'status': status}

    # --- HANDLE SUBSCRIPTION UPDATES & RENEWALS ---
    elif event_type in ['subscription.activated', 'subscription.updated']:
        # --- Improvement 2: Validate Product Price ---
        items = data.get("items", [])
        if items:
            price_id = items[0].get("price_id")
            expected_price_id = os.environ.get("PADDLE_PRICE_ID")
            if expected_price_id and price_id != expected_price_id:
                logger.info(f"Subscription {data.get('id')} has different price_id {price_id}. Ignoring.")
                return {'status': 'ignored', 'reason': 'wrong_product'}

        sub_status = data.get('status')
        firebase_uid = get_firebase_uid(data)
        
        if not firebase_uid:
            logger.warning(f"Received {event_type} for sub {data.get('id')} with no firebase_uid.")
            return {'status': 'ignored'}

        if sub_status == 'active':
            # Ensure user is Pro (e.g. on renewal)
            upgrade_user_to_pro(firebase_uid, f"sub_event_{data.get('id')}_{int(time.time())}")
            return {'status': 'confirmed_active'}
        elif sub_status == 'past_due':
            logger.warning(f"Subscription {data.get('id')} is past_due for user {firebase_uid}")
            # Optional: Add field to firestore to show warning in app
            return {'status': 'logged_past_due'}
        
        return {'status': 'ignored', 'reason': f'unhandled_sub_status_{sub_status}'}

    # --- HANDLE CANCELLATION/TERMINATION ---
    elif event_type == 'subscription.canceled':
        firebase_uid = get_firebase_uid(data)
        if firebase_uid:
            downgrade_user_to_free(firebase_uid)
            return {'status': 'downgraded'}
        return {'status': 'ignored', 'reason': 'missing_uid'}

    else:
        logger.info(f"Ignoring unhandled event type: {event_type}")
        return {'status': 'ignored', 'reason': 'unhandled_event_type'}
