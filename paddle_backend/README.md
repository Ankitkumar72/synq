# Synq Paddle Backend (FastAPI)

This is the Python/FastAPI backend that securely generates checkout URLs and handles incoming webhooks for the Paddle billing integration.

## Local Development
1. Create a `.env` file from `.env.example`.
2. Add your Paddle Sandbox API Key and Webhook Secret.
3. Download your Firebase `synq-firebase-adminsdk.json` into this folder.
4. Run locally: `uvicorn main:app --reload`
5. The local backend runs on `http://localhost:8000`.

## Production Deployment (Hugging Face Spaces)

Deploy the backend to Hugging Face Spaces for a robust, free Docker environment that stays awake to process webhooks. We pass the sensitive Firebase JSON as a Base64 string in the environment variables.

### Step 1: Create the Space
1. Create a free account at [Hugging Face](https://huggingface.co/) and click your profile picture to go to **New Space**.
2. Give it a name (e.g., `synq-paddle-webhook`).
3. For the SDK, select **Docker** and choose the **Blank** template.
4. Keep the Space Hardware as **CPU Basic (Free)** and click **Create**.

### Step 2: Configure Environment Variables
1. Go to your new Space's **Settings** tab. Scroll down to the **Variables and secrets** section.
2. Click **New secret**. Add the following secrets:
   - `PADDLE_API_KEY`: Your Paddle Production/Sandbox API Key
   - `PADDLE_WEBHOOK_SECRET`: Your Paddle Webhook Secret
   - `PADDLE_MONTHLY_PRICE_ID`: Price ID for the monthly plan
   - `PADDLE_YEARLY_PRICE_ID`: Price ID for the yearly plan
   - `FIREBASE_PROJECT_ID`: `synq-task-app`
   - `FIREBASE_ADMIN_BASE64`: The giant Base64 string output from your conversion script.
   - `ENVIRONMENT`: `production`

### Step 3: Upload Code and Verify
1. Navigate back to the **Files** tab in your Space.
2. Click **Add file > Upload files**, and drag in your `main.py`, `requirements.txt`, `Dockerfile`, `auth.py`, `firestore_client.py`, `paddle_client.py` and `webhook.py`.
3. Add a commit message and click **Commit changes to main**.
4. Hugging Face will instantly build the Docker container. Once it says "Running", visit `https://<your-huggingface-username>-<your-space-name>.hf.space/health` to verify it returns `{"status": "ok"}`.

### Step 4: Webhook Configuration
1. In your Paddle Dashboard, go to **Developer Tools** > **Webhooks**.
2. Add a new Webhook Endpoint: `https://<your-huggingface-username>-<your-space-name>.hf.space/paddle-webhook`
3. Select the event `transaction.completed`.
4. Copy the new Webhook Secret under the webhook's settings and update `PADDLE_WEBHOOK_SECRET` in Hugging Face.

## Maintenance & Runbook
- **Rotating Keys**: If your Paddle keys are compromised, generate new ones in the Paddle Dashboard and update the Hugging Face Secrets.
- **Webhook Failures**: Hugging Face logs will output structured logs (`INFO`, `ERROR`, etc.). If a webhook fails due to a missing Firebase UID, it logs `WARNING: No firebase_uid... Cannot upgrade user.` but returns `200 OK` to Paddle (so Paddle stops retrying unfixable data).
- **Idempotency**: Webhooks are fully idempotent. If Paddle retries a webhook that already upgraded a user, the backend skips it safely and logs `duplicate_ignored`.
