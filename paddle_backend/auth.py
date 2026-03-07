import firebase_admin
from firebase_admin import credentials, auth
from fastapi import Header, HTTPException
import os

# Initialise Firebase Admin SDK once at import time
# Uses GOOGLE_APPLICATION_CREDENTIALS env var (points to service account JSON on Railway)
if not firebase_admin._apps:
    cred_path = os.environ['GOOGLE_APPLICATION_CREDENTIALS']
    if not os.path.isabs(cred_path):
        cred_path = os.path.join(os.path.dirname(__file__), cred_path)
    cred_path = os.path.normpath(cred_path)
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)


async def get_uid(authorization: str = Header(...)) -> str:
    """
    FastAPI dependency: verifies the Firebase ID token from the Authorization header.
    Returns the authenticated user's uid, or raises HTTP 401.
    
    Flutter sends: Authorization: Bearer <firebase_id_token>
    """
    if not authorization.startswith('Bearer '):
        raise HTTPException(status_code=401, detail='Missing Bearer token')
    
    id_token = authorization.split(' ', 1)[1]
    
    try:
        decoded = auth.verify_id_token(id_token)
        return decoded['uid']
    except Exception:
        raise HTTPException(status_code=401, detail='Invalid or expired token')
