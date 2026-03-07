from paddle_billing import Client, Environment, Options
from paddle_billing.Resources.Transactions import Operations as transaction_ops
from paddle_billing.Resources.Transactions.Operations.Create import TransactionCreateItem
import os

# Determine environment from env var
_env = Environment.SANDBOX if os.environ.get('ENVIRONMENT', 'development') == 'development' else Environment.PRODUCTION

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
