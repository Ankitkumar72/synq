import logging
from fastapi import FastAPI, Depends, Request, HTTPException
from pydantic import BaseModel
from fastapi.responses import HTMLResponse

from dotenv import load_dotenv
load_dotenv()

from auth import get_uid
from paddle_client import create_checkout_url
from webhook import handle_paddle_webhook

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = FastAPI(title="Synq Paddle Backend")


class CheckoutResponse(BaseModel):
    checkout_url: str


@app.get('/health')
async def health():
    """Health check endpoint for Railway monitoring."""
    return {'status': 'ok'}


@app.get('/paddle-checkout', response_class=HTMLResponse)
async def paddle_checkout_page(request: Request):
    """
    Local testing endpoint to handle the Paddle default payment link redirect.
    Because the Flutter emulator cannot reach https://localhost/?_ptxn=..., 
    the app replaces the domain with the backend IP and opens this page.
    """
    ptxn = request.query_params.get('_ptxn', 'None')
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Paddle Checkout Simulator</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background-color: #f3f6fc; color: #333; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; }}
            .card {{ background: white; padding: 2rem; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); text-align: center; max-width: 400px; }}
            .btn {{ background: #0066FF; color: white; border: none; padding: 12px 24px; border-radius: 6px; font-weight: bold; cursor: pointer; margin-top: 1rem; text-decoration: none; display: inline-block; }}
        </style>
    </head>
    <body style="background-color: #f3f6fc; display: flex; justify-content: center; align-items: center; height: 100vh; font-family: sans-serif;">
        <div class="card" style="text-align: center;">
            <h2>Test Checkout Received!</h2>
            <p>Paddle Transaction ID (ptxn):<br/><strong>{ptxn}</strong></p>
            <p><i>In a real web environment, Paddle.js would automatically open the checkout overlay now. For local mobile testing, this confirms your backend successfully returned the transaction URL and the flutter app successfully opened it!</i></p>
        </div>
    </body>
    </html>
    """


@app.post('/create-checkout', response_model=CheckoutResponse)
async def create_checkout(uid: str = Depends(get_uid)):
    """
    Authenticated endpoint. uid comes from verified Firebase ID token.
    Flutter sends: Authorization: Bearer <firebase_id_token>
    
    Returns a Paddle-hosted checkout URL for the Pro subscription.
    """
    logger.info(f"Initiating checkout creation for user: {uid}")
    try:
        url = create_checkout_url(uid)
        logger.info(f"Checkout URL successfully generated for user: {uid}")
        return CheckoutResponse(checkout_url=url)
    except Exception as e:
        logger.error(f"Failed to create checkout URL for user {uid}: {str(e)}")
        raise HTTPException(status_code=400, detail="Failed to create checkout session")


@app.post('/paddle-webhook')
async def paddle_webhook(request: Request):
    """
    Unauthenticated webhook endpoint — Paddle calls this directly.
    Security is HMAC signature verification only.
    
    CRITICAL: Do not add body-parsing middleware before this route.
    The raw body is needed for HMAC validation.
    """
    return await handle_paddle_webhook(request)
