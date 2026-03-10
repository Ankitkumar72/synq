import firebase_admin
from firebase_admin import credentials, auth
from fastapi import Header, HTTPException
import os
import base64
import json
import logging


logger = logging.getLogger(__name__)

def _initialize_firebase_admin() -> None:
    firebase_b64 = os.environ.get("FIREBASE_ADMIN_BASE64")
    project_id = os.environ.get("FIREBASE_PROJECT_ID")

    # 1) Preferred explicit secret path for most hosts.
    if firebase_b64:
        clean_b64 = "".join(firebase_b64.split())
        decoded_bytes = base64.b64decode(clean_b64)
        cred_dict = json.loads(decoded_bytes.decode("utf-8"))
        cred = credentials.Certificate(cred_dict)
        options = {"projectId": project_id} if project_id else None
        firebase_admin.initialize_app(cred, options)
        logger.info("Firebase Admin initialized via FIREBASE_ADMIN_BASE64")
        return

    # 2) Local development file fallback.
    cred_path = os.environ.get(
        "GOOGLE_APPLICATION_CREDENTIALS",
        "synq-firebase-adminsdk.json",
    )
    if not os.path.isabs(cred_path):
        cred_path = os.path.join(os.path.dirname(__file__), cred_path)
    cred_path = os.path.normpath(cred_path)

    if os.path.exists(cred_path):
        cred = credentials.Certificate(cred_path)
        options = {"projectId": project_id} if project_id else None
        firebase_admin.initialize_app(cred, options)
        logger.info("Firebase Admin initialized via service account file")
        return

    # 3) Cloud Run / GCP fallback via workload identity.
    try:
        cred = credentials.ApplicationDefault()
        options = {"projectId": project_id} if project_id else None
        firebase_admin.initialize_app(cred, options)
        logger.info("Firebase Admin initialized via Application Default Credentials")
        return
    except Exception as exc:
        raise ValueError(
            "Failed to initialize Firebase Admin credentials. Provide "
            "FIREBASE_ADMIN_BASE64, a valid GOOGLE_APPLICATION_CREDENTIALS file, "
            "or configure Application Default Credentials in the runtime."
        ) from exc


if not firebase_admin._apps:
    _initialize_firebase_admin()


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
    except Exception:
        logger.warning("Failed to verify Firebase ID token")
        raise HTTPException(status_code=401, detail='Invalid or expired token')
