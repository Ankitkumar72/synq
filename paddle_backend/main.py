import logging
import os
from typing import Literal

from fastapi import FastAPI, Depends, Request, HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel

from dotenv import load_dotenv
load_dotenv()

from auth import get_uid
from paddle_client import create_checkout_url
from webhook import handle_paddle_webhook


# Logging configuration
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


app = FastAPI(title="Synq Paddle Backend")


class CheckoutRequest(BaseModel):
    plan_slug: Literal['monthly', 'yearly']

class CheckoutResponse(BaseModel):
    checkout_url: str


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {"status": "ok"}


@app.get("/paddle-checkout", response_class=HTMLResponse)
async def paddle_checkout_page(request: Request):
    """
    Local testing endpoint to handle the Paddle default payment link redirect.
    Because the Flutter emulator cannot reach https://localhost/?_ptxn=..., 
    the app replaces the domain with the backend IP and opens this page.
    """

    ptxn = request.query_params.get("_ptxn", "None")

    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Paddle Checkout Simulator</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {{
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                background-color: #f3f6fc;
                color: #333;
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                height: 100vh;
                margin: 0;
            }}
            .card {{
                background: white;
                padding: 2rem;
                border-radius: 12px;
                box-shadow: 0 4px 6px rgba(0,0,0,0.1);
                text-align: center;
                max-width: 400px;
            }}
            .btn {{
                background: #0066FF;
                color: white;
                border: none;
                padding: 12px 24px;
                border-radius: 6px;
                font-weight: bold;
                cursor: pointer;
                margin-top: 1rem;
                text-decoration: none;
                display: inline-block;
            }}
        </style>
    </head>

    <body>
        <div class="card">
            <h2>Test Checkout Received!</h2>
            <p>Paddle Transaction ID (ptxn):<br/><strong>{ptxn}</strong></p>
            <p>
            <i>
            In a real web environment, Paddle.js would automatically open the checkout overlay.
            For local mobile testing, this confirms your backend successfully returned the
            transaction URL and the Flutter app successfully opened it.
            </i>
            </p>
        </div>
    </body>
    </html>
    """


@app.post("/create-checkout", response_model=CheckoutResponse)
async def create_checkout(request: CheckoutRequest, uid: str = Depends(get_uid)):
    """
    Authenticated endpoint.

    uid comes from verified Firebase ID token.
    Flutter sends:
        Authorization: Bearer <firebase_id_token>
        Body: {"plan_slug": "monthly"}

    Returns a Paddle-hosted checkout URL for the selected subscription plan.
    """

    # --- Security: Map Slugs to internal Price IDs ---
    slug_to_price = {
        'monthly': os.environ.get('PADDLE_MONTHLY_PRICE_ID'),
        'yearly': os.environ.get('PADDLE_YEARLY_PRICE_ID'),
    }

    price_id = slug_to_price.get(request.plan_slug)

    if not price_id:
        logger.error("Price ID missing for configured plan: %s", request.plan_slug)
        raise HTTPException(
            status_code=500,
            detail="Selected plan is currently unavailable"
        )

    logger.info(f"Initiating checkout creation for user: {uid}, plan: {request.plan_slug}")

    try:
        url = create_checkout_url(uid, price_id)
        logger.info(f"Checkout URL successfully generated for user: {uid}")
        return CheckoutResponse(checkout_url=url)

    except Exception as e:
        logger.error(f"Failed to create checkout URL for user {uid}: {str(e)}")
        raise HTTPException(
            status_code=400,
            detail="Failed to create checkout session"
        )


@app.post("/paddle-webhook")
async def paddle_webhook(request: Request):
    """
    Unauthenticated webhook endpoint — Paddle calls this directly.

    Security is HMAC signature verification only.

    CRITICAL:
    Do not add body-parsing middleware before this route.
    The raw body is needed for HMAC validation.
    """

    return await handle_paddle_webhook(request)


# -------------------------------
# Server startup
# -------------------------------

if __name__ == "__main__":

    host = os.environ.get("HOST", "0.0.0.0")
    port = int(os.environ.get("PORT", 7860))

    logger.info(f"Starting Synq Paddle Backend Server on {host}:{port}")

    import uvicorn
    uvicorn.run(app, host=host, port=port)
