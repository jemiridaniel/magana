# WhatsApp: create the Meta app and test number

Magana on WhatsApp (design canvas W1–W5) is for adults. Send a photo of a page and Magana sends back the text exactly as printed, then a voice note. It also runs the Ibà quick check for a nurse call-back.

The code is ready on the server at **https://api.magana.ng/whatsapp/webhook**. It answers "not configured" until the settings below are in the server's `.env`.

**The test number is free.** It can message up to 5 phone numbers that you verify. Nothing here costs money. Going live with a real number later means business verification, and Meta may charge per conversation; agree that before doing it.

**Never paste the token or app secret into a chat, an email or the repo.** They go only into the server's `.env`.

## 1. Create the app (about 10 minutes)

1. Go to **developers.facebook.com** and sign in with the Facebook account that will own Magana's WhatsApp. Choose **My Apps → Create app**.
2. Use case: **Other**, then app type **Business**. App name: `Magana`. Contact email: `maganasupport@gmail.com`. If it asks for a business portfolio, create one called `Magana`.
3. On the app's dashboard, find **WhatsApp** and choose **Set up**. Meta creates a test WhatsApp business account and a **test phone number**.

## 2. The numbers you need

In the left menu, open **WhatsApp → API Setup**:

1. Under **From**, the test number is selected. Copy its **Phone number ID** (a long number, not the phone number itself).
2. Under **To**, choose **Manage phone number list** and add your own WhatsApp number. Meta sends it a code; enter it. Add up to 4 testers the same way.
3. The **temporary access token** shown there lasts only 24 hours. For a token that lasts:
   1. Open **business.facebook.com → Settings → Users → System users → Add**. Name: `magana-server`, role **Admin**.
   2. Choose **Add assets → Apps → Magana**, with full control.
   3. Choose **Generate token → app Magana**, expiry **Never**. Tick the permissions `whatsapp_business_messaging` and `whatsapp_business_management`.
   4. Copy the token **once**, straight into the server (step 3).
4. Open **App settings → Basic** and copy the **App secret** (choose **Show**).
5. Make up a verify token, any long random word. On your Mac: `openssl rand -hex 16`.

## 3. Put them on the server

```bash
ssh -i ~/.ssh/magana-london.pem ubuntu@35.178.64.255
nano ~/srv/magana/.env
```

Add these lines, with your values:

```bash
WHATSAPP_TOKEN=...              # the system user token
WHATSAPP_PHONE_NUMBER_ID=...    # from API Setup
WHATSAPP_APP_SECRET=...         # App settings → Basic
WHATSAPP_VERIFY_TOKEN=...       # the random word you made
WHATSAPP_VOICE=off              # voice notes need a bigger server (docs/FINDINGS.md)
```

Then restart the backend so it reads them:

```bash
cd ~/srv/magana && sudo docker compose -f docker-compose.prod.yml up -d
```

## 4. Connect the webhook

1. In the app, open **WhatsApp → Configuration → Webhook → Edit**.
2. **Callback URL:** `https://api.magana.ng/whatsapp/webhook`
3. **Verify token:** the random word from step 2.5. Choose **Verify and save**. Meta calls the server, and Magana echoes Meta's challenge only if the token matches.
4. Under **Webhook fields**, choose **Manage** and subscribe to **messages**.

## 5. Try it

From your own phone, send **Hi** to the test number. You should get:

1. The language list. Choose one.
2. "Are you 18 or older?". Choose Yes.
3. Send a photo of a medicine label. You get "Reading your page…", the lines exactly as printed, any warnings, then the buttons Read again / Health worker / Help.

With `WHATSAPP_VOICE=off`, Magana says once that voice notes aren't ready yet.

If nothing comes back, check the backend log:

```bash
sudo docker compose -f ~/srv/magana/docker-compose.prod.yml logs --tail 50 magana
```

Logs show `whatsapp in kind=…` lines with a short hashed user id, never a phone number or message text. A `401 bad_signature` means the app secret on the server doesn't match the app's.

## How it stays safe

- **Signed requests only.** Every message from Meta carries `X-Hub-Signature-256`, an HMAC of the body with the app secret. Anything unsigned or wrongly signed gets 401 and is never read. Meta doesn't send the Magana app key, so the webhook doesn't need it; the signature replaces it.
- **Secrets live only in the server's `.env`** (not in GitHub, not in the app).
- **The free messages are counted** (`MAGANA_DATA_DIR/whatsapp/usage.json`, per month):
  - At **800** sent, Magana logs a warning, and posts it to `MAGANA_ALERT_WEBHOOK_URL` if that is set.
  - At **950**, new photos and checks get "Magana on WhatsApp has reached its limit for this month".
  - At **1,000**, nothing more is sent except the emergency message ("go to a clinic now or call 112"), which always goes.
  - `WHATSAPP_MONTHLY_LIMIT` changes the 1,000.
- **Privacy:** see docs/PRIVACY.md, "WhatsApp".

## Call-back requests

When the quick check ends, Magana logs a call-back request with a reference such as `MG-4821`. The user can change the number or cancel it.

- **Until a nurse desk is connected,** requests are kept on the server in `MAGANA_DATA_DIR/whatsapp/callbacks.jsonl`: reference, phone number, language, priority, time and status. Never the answers. Each is deleted after 30 days.
- **Read them with:**
  ```bash
  sudo docker compose -f ~/srv/magana/docker-compose.prod.yml exec magana cat /data/whatsapp/callbacks.jsonl
  ```
- **With `MAGANA_CALLBACK_URL` set,** each request is also sent to the desk.
