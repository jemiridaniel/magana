# Deploying the Magana backend on AWS (EC2, London)

One small EC2 instance in **eu-west-2 (London)** runs everything with Docker:

```
phone app ──HTTPS──▶ Caddy (ports 80/443, automatic certificates)
                       └──▶ Magana backend (FastAPI, Tesseract or PaddleOCR)
                              └──▶ Ibà (iba-natlas /v1 triage rules, internal only)
```

- **Files:** `docker-compose.prod.yml`, `deploy/Caddyfile`, `deploy/.env.example`, `deploy/setup-server.sh`, plus the Mac scripts `scripts/aws-instance.sh` and `scripts/deploy.sh`.
- **Secrets** live only in `~/srv/magana/.env` on the server (`chmod 600`), never in the repo.
- **API key:** the app sends `X-Magana-Key` with every request. The backend refuses anything without it except `/health`. The key is built into the app, so it keeps out bots and casual callers, not a determined attacker who unpacks the APK.

## 1. What it costs (taken from the $100 free-plan credit)

| Item | Price (eu-west-2) | Per month if always on |
|---|---|---|
| t3.small (2 vCPU, 2 GiB): start here, Tesseract | $0.0236 per hour ¹ | about $17.2 |
| c7i-flex.large (2 vCPU, 4 GiB): for PaddleOCR | $0.1008 per hour ¹ | about $73.6 |
| Elastic IP (public IPv4), charged even while stopped | $0.005 per hour ² | about $3.65 |
| 30 GiB gp3 disk, charged even while stopped | about $0.09 per GiB-month ³ | about $2.8 |
| Data out to the internet | first 100 GB per month free | $0 for testing |

- **t3.small, always on:** about **$24 a month**, so the $100 credit lasts about 4 months. Stopping it outside testing hours (`scripts/aws-instance.sh stop`) leaves only about $6.5 a month for the IP and disk.
- **c7i-flex.large, always on:** about **$80 a month**, so the credit lasts about 5 weeks. Use it only while measuring PaddleOCR.

¹ DoiT instance-price pages for [t3.small](https://www.doit.com/compute/spot/eu-west-2/t3.small) and [c7i-flex.large](https://www.doit.com/compute/spot/eu-west-2/c7i-flex.large). These are third-party; confirm in the [AWS Pricing Calculator](https://calculator.aws/).
² [AWS public IPv4 address charge](https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights).
³ An approximation; check gp3 for London in the Pricing Calculator.

**Free plan rules** (accounts created after 15 July 2025; [AWS announcement](https://aws.amazon.com/about-aws/whats-new/2025/07/aws-free-tier-credits-month-free-plan/)):
- The plan ends after 6 months or when the credit is used up, whichever comes first.
- Only some instance types can be launched. A secondary source lists t3.small and c7i-flex.large among them ([dev.to](https://dev.to/ricky_rios/aws-free-tier-2025-what-changed-whats-included-and-how-to-use-it-7a6)); the launch screen marks eligible types.
- **Before anything would cost real money beyond the credit, stop and decide.** Don't upgrade to a paid plan without agreeing it first.

## 2. Budget alerts at $25, $50 and $75 (do this first)

1. Sign in to the AWS console. In the top-right **Region** menu choose **Europe (London) eu-west-2**. Budgets are global, but everything else below is in London.
2. Search **Billing and Cost Management**, open it, then in the left menu choose **Budgets**, then **Create budget**.
3. Choose **Customize (advanced)**, then **Cost budget**, then **Next**.
4. **Name:** `magana-monthly`. **Period:** Monthly. **Renewal:** Recurring. **Budgeting method:** Fixed. **Budgeted amount:** `100`.
5. Under **Advanced options**, untick **Credits** (and **Refunds**). Otherwise the credit hides the spend and the budget shows $0 until the credit is gone.
6. **Next.** Add three alert thresholds, each with **Trigger: Actual**, **Threshold type: Absolute value**, and your email as recipient:
   - `25` (USD)
   - `50`
   - `75`
7. **Next → Create budget.** Setting up a budget is also one of the free plan's "earn $20 credit" activities.

## 3. Key pair (for SSH)

1. Search **EC2**. In the left menu, under **Network & Security**, choose **Key Pairs**, then **Create key pair**.
2. **Name:** `magana-london`. **Type:** ED25519. **Format:** .pem. Choose **Create key pair**; the file downloads.
3. On your Mac:
   ```bash
   mkdir -p ~/.ssh && mv ~/Downloads/magana-london.pem ~/.ssh/ && chmod 400 ~/.ssh/magana-london.pem
   ```
   Back it up somewhere safe. AWS can't send it again.

## 4. Security group: 80 and 443 to everyone, SSH only from you

1. **EC2 → Network & Security → Security Groups → Create security group.**
2. **Name:** `magana-web`. **Description:** `Magana API: HTTP, HTTPS, SSH from my IP`. **VPC:** the default.
3. **Inbound rules → Add rule**, three times:
   - **HTTP**, port 80, source **Anywhere-IPv4** (`0.0.0.0/0`). Caddy needs port 80 to get certificates and to redirect to HTTPS.
   - **HTTPS**, port 443, source **Anywhere-IPv4**.
   - **SSH**, port 22, source **My IP**. The console fills in your current address. If your IP changes, edit this rule.
4. Leave outbound as it is (all allowed) and choose **Create security group**.

## 5. Launch the instance

1. **EC2 → Instances → Launch instances.**
2. **Name:** `magana-backend`.
3. **Application and OS Images:** **Ubuntu**, then **Ubuntu Server 24.04 LTS (HVM), SSD Volume Type**, architecture **64-bit (x86)**.
4. **Instance type:** **t3.small**.
5. **Key pair:** `magana-london`.
6. **Network settings → Edit:**
   - **Auto-assign public IP:** Enable. The Elastic IP in step 6 replaces it.
   - **Firewall:** **Select existing security group**, then `magana-web`.
7. **Configure storage:** **30** GiB, **gp3**. PaddleOCR images and models need the room.
8. **Advanced details → Credit specification:** **Standard**. The default, "Unlimited", lets a T3 burst past its baseline and bill extra for it.
9. Choose **Launch instance**, then **View all instances**. Wait until **Instance state** is *Running* and the **Status check** passes.
10. Copy the **Instance ID** (`i-…`).

## 6. Elastic IP (a stable address, so the app's URL never changes)

1. **EC2 → Network & Security → Elastic IPs → Allocate Elastic IP address → Allocate.**
2. Select the new address, then **Actions → Associate Elastic IP address**. **Instance:** `magana-backend`. Choose **Associate**.
3. Note the address, for example `18.130.12.34`. Your HTTPS address is then **`https://18-130-12-34.sslip.io`**: the IP with dashes, plus `.sslip.io`, a free DNS name that points at the IP. With a real domain later, point an A record at the IP and use that name instead.

## 7. Set up the server (about 10 minutes)

```bash
ssh -i ~/.ssh/magana-london.pem ubuntu@18.130.12.34
curl -fsSL https://raw.githubusercontent.com/jemiridaniel/magana/main/deploy/setup-server.sh | bash
nano ~/srv/magana/.env
```

In `.env`, set:
- `MAGANA_DOMAIN=18-130-12-34.sslip.io`
- `MAGANA_API_KEY=` and `IBA_API_KEY=`, each a different value from `openssl rand -hex 32`.

Keep the `MAGANA_API_KEY` value: the APK is built with it (`docs/TESTER_INSTALL.md`, "For the team"). Then:

```bash
cd ~/srv/magana && sudo docker compose -f docker-compose.prod.yml up -d --build
curl https://18-130-12-34.sslip.io/health
```

`/health` answers `{"status":"ok", "iba": {...}}`. The first certificate takes a few seconds. If it fails, check `sudo docker compose -f docker-compose.prod.yml logs caddy`. Port 80 must be open for Let's Encrypt.

## 8. Start, stop and update from your Mac

1. **Credentials for the scripts.** Use a narrow IAM user, not your root account:
   1. **IAM → Users → Create user** `magana-ops` (no console access).
   2. **Attach policies directly → Create policy → JSON**, with your account ID and instance ID filled in:
      ```json
      {
        "Version": "2012-10-17",
        "Statement": [
          {"Effect": "Allow", "Action": ["ec2:StartInstances", "ec2:StopInstances"],
           "Resource": "arn:aws:ec2:eu-west-2:<ACCOUNT_ID>:instance/<INSTANCE_ID>"},
          {"Effect": "Allow", "Action": "ec2:DescribeInstances", "Resource": "*"}
        ]
      }
      ```
      Name it `magana-start-stop` and attach it.
   3. Open the user, then **Security credentials → Create access key** (use case: Command Line Interface).
   4. On the Mac: `aws configure --profile magana`, entering the key, the secret, region `eu-west-2` and output `json`.
2. Create `~/.magana/aws.env` (outside the repo):
   ```bash
   MAGANA_INSTANCE_ID=i-0123456789abcdef0
   AWS_PROFILE=magana
   AWS_REGION=eu-west-2
   MAGANA_HOST=18.130.12.34
   MAGANA_SSH_KEY=~/.ssh/magana-london.pem
   ```
3. Then:
   ```bash
   scripts/aws-instance.sh start    # waits until https://…sslip.io/health answers
   scripts/aws-instance.sh stop     # stop when nobody is testing, to save credit
   scripts/aws-instance.sh status
   scripts/deploy.sh                # pull the latest code on the server and rebuild
   ```

The containers restart by themselves when the instance starts (`restart: unless-stopped`).

## 9. Switching to PaddleOCR (one line in .env)

> **Measure before real users.** Every number is now re-read from its own crop in PaddleOCR mode too, by Tesseract. The backend runs a start-up self-test and **refuses to start** if any number isn't re-read (docs/FINDINGS.md). PaddleOCR's memory use on 4 GiB and its real word positions have **not been measured** yet: check `docker stats` and read a few test pages first.

1. `scripts/aws-instance.sh stop`.
2. **EC2 → Instances →** select `magana-backend` → **Actions → Instance settings → Change instance type → c7i-flex.large → Apply.**
3. `scripts/aws-instance.sh start`, then on the server:
   ```bash
   cd ~/srv/magana && sed -i 's/^OCR_ENGINE=.*/OCR_ENGINE=paddle/' .env
   sudo docker compose -f docker-compose.prod.yml up -d --build    # about 3 GB more image
   sudo docker stats --no-stream                                   # record memory in FINDINGS.md
   ```

To go back, set `OCR_ENGINE=tesseract`, run the same command, and change the type back to t3.small.

## 10. Explanations (N-ATLaS)

`EXPLAIN_ENGINE=stub` keeps Explain as a preview. To use a served N-ATLaS (docs/MODELS.md), set `EXPLAIN_ENGINE`, `EXPLAIN_URL` and `EXPLAIN_API_KEY` in `.env` and restart:

```bash
sudo docker compose -f docker-compose.prod.yml up -d
```

## 10a. The web app (PWA) at /app

The same Caddy serves the Flutter web build at `https://<host>/app/` from `deploy/web/` on the server (git-ignored, mounted read-only into Caddy). From your Mac, with `MAGANA_API` and `MAGANA_API_KEY` in `~/.magana/app.env` and `MAGANA_HOST` in `~/.magana/aws.env`:

```bash
scripts/deploy-web.sh
```

It builds with `--base-href /app/`, fills in the service worker's file list and copies `build/web/` to the server. No restart is needed. `index.html`, `magana_sw.js`, `flutter_bootstrap.js` and `manifest.json` are served with `Cache-Control: no-cache`, so testers get the new version the next time they open it online.

**The web API key is public:** anyone can read it from the JavaScript. The backend therefore limits requests per IP and per device (`X-Magana-Device`), and answers `429 too_many_requests` with `Retry-After`. Defaults are per minute, in `.env`:

| Setting | Default | Applies to |
|---|---|---|
| `RATE_IP_PER_MIN` | 120 | every request from one IP |
| `RATE_DEVICE_PER_MIN` | 60 | every request from one device |
| `RATE_HEAVY_IP_PER_MIN` | 30 | `/read`, `/asr`, `/explain` from one IP |
| `RATE_HEAVY_DEVICE_PER_MIN` | 12 | the same, from one device |

A school's testers may share one IP behind a router. If they hit the limit, raise the two IP settings. `/health` is never limited. The limits are kept in memory, so a restart resets them.

## 10b. Teacher portal quizzes

Quizzes teachers write in the portal are saved in the `magana_data` volume (`MAGANA_DATA_DIR=/data`). They are teacher content, never learner data. Back it up with the server:

```bash
sudo docker run --rm -v magana_magana_data:/data -v "$PWD":/backup alpine tar czf /backup/quizzes.tgz -C /data .
```

Saving and assigning quizzes needs `MAGANA_TEACHER_KEY` in `.env` (`openssl rand -hex 24`), sent by the portal as `X-Magana-Teacher-Key`. The app's API key can't be used: it is public. Without the key, a production server refuses quiz writes (`teacher_portal_off`). Learners read assigned quizzes with the ordinary app key.

## 11. Logs and troubleshooting

```bash
cd ~/srv/magana
sudo docker compose -f docker-compose.prod.yml ps
sudo docker compose -f docker-compose.prod.yml logs -f magana   # never contains photos or triage answers
```

- **No HTTPS:** check that the security group allows 80 and 443, and that `MAGANA_DOMAIN` is exactly the IP with dashes plus `.sslip.io`.
- **401 `bad_api_key` from the app:** the APK was built with a different `MAGANA_API_KEY`.
- **Out of memory on t3.small:** check swap (`swapon --show`). The setup script adds 2 GB.
