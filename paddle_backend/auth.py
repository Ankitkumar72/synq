import firebase_admin
from firebase_admin import credentials, auth
from fastapi import Header, HTTPException
import os
import base64
import json

# Fetch the Base64 string from the environment
firebase_b64 = os.environ.get("FIREBASE_ADMIN_BASE64")

if not firebase_admin._apps:
    if firebase_b64:
        # Decode the Base64 string back into a JSON dictionary
        # Strip whitespace/newlines that might have been added during copy-paste
        clean_b64 = "".join(firebase_b64.split())
        decoded_bytes = base64.b64decode(clean_b64)
        cred_dict = json.loads(decoded_bytes.decode('utf-8'))
        
        # Initialize the Firebase Admin SDK using the dictionary
        cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(cred)
    else:
        # Fallback for local development if developers haven't set BASE64 yet
        cred_path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS', 'synq-firebase-adminsdk.json')
        if not os.path.isabs(cred_path):
            cred_path = os.path.join(os.path.dirname(__file__), cred_path)
        cred_path = os.path.normpath(cred_path)
        if os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
        else:
            raise ValueError("FIREBASE_ADMIN_BASE64 env var is missing and no local JSON found.")


from typing import Optional

async def get_uid(authorization: Optional[str] = Header(None)) -> str:
    """
    FastAPI dependency: verifies the Firebase ID token from the Authorization header.
    Returns the authenticated user's uid, or raises HTTP 401.
    
    Flutter sends: Authorization: Bearer <firebase_id_token>
    """
    if not authorization or not authorization.startswith('Bearer '):
        raise HTTPException(status_code=401, detail='Missing Bearer token')
    
    id_token = authorization.split(' ', 1)[1]
    
    try:
        decoded = auth.verify_id_token(id_token)
        return decoded['uid']
    except Exception as e:
        raise HTTPException(status_code=401, detail=f'Invalid or expired token: {str(e)}')
