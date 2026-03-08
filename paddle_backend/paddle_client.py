from paddle_billing import Client, Environment, Options
from paddle_billing.Resources.Transactions import Operations as transaction_ops
from paddle_billing.Resources.Transactions.Operations.Create import TransactionCreateItem
import os
import logging

logger = logging.getLogger(__name__)

# Determine environment: Default to SANDBOX unless ENVIRONMENT is explicitly 'production'
_env_str = os.environ.get('ENVIRONMENT', 'sandbox').lower()
_env = Environment.PRODUCTION if _env_str == 'production' else Environment.SANDBOX

paddle = Client(
    os.environ['PADDLE_API_KEY'],
    options=Options(_env),
)

def create_checkout_url(firebase_uid: str) -> str:
    """
    Creates a Paddle transaction for the Pro subscription price.
    Embeds the firebase_uid in custom_data so the webhook knows who paid.
    Returns the hosted checkout URL.
    """
    try:
        transaction = paddle.transactions.create(
            transaction_ops.CreateTransaction(
                items=[
                    TransactionCreateItem(
                        price_id=os.environ['PADDLE_PRICE_ID'],
                        quantity=1,
                    ),
                ],
                custom_data={'firebase_uid': firebase_uid},
            )
        )
        return transaction.checkout.url
    except Exception as e:
        logger.error(f"Paddle API Error: {str(e)}")
        raise e
