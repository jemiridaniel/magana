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
4. **Outbound rules:** keep the default **All traffic → 0.0.0.0/0**. If it's missing, the server can't reach GitHub, Docker or even Ubuntu's mirror: every download times out, while SSH in still works (this happened on the first deploy).
5. Choose **Create security group**.

**SSH from a changing network** (travelling between cities): edit the SSH rule's **Source** to **My IP** again when your address changes, which takes 30 seconds. Don't open port 22 to everyone.

## 5. Launch the instance

1. **EC2 → Instances → Launch instances.**
2. **Name:** `magana-backend`.
3. **Application and OS Images:** **Ubuntu**, then **Ubuntu Server 24.04 LTS (HVM), SSD Volume Type**, architecture **64-bit (x86)**.
4. **Instance type:** **t3.small**.
5. **Key pair:** `magana-london`.
6. **Network settings → Edit:**
   - **Auto-assign public IP:** Enable. The Elastic IP in step 6 replaces it.
   - **Firewall:** **Select existing security group**, then `magana-web`.
7. **Configure storage:** **20** GiB **gp3** is enough for Tesseract (the first deploy uses 6.9 GB). Use **30** GiB if you'll try PaddleOCR.
8. **Advanced details → Credit specification:** **Standard**. The default, "Unlimited", lets a T3 burst past its baseline and bill extra for it.
9. Choose **Launch instance**, then **View all instances**. Wait until **Instance state** is *Running* and the **Status check** passes.
10. Copy the **Instance ID** (`i-…`).

## 6. Elastic IP (a stable address, so the app's URL never changes)

1. **EC2 → Network & Security → Elastic IPs → Allocate Elastic IP address → Allocate.** Allocate **one**: every allocated address costs about $3.65 a month, attached or not. Release any spare.
2. Select the new address, then **Actions → Associate Elastic IP address**. **Instance:** pick `magana-backend` from the list (typing the ID isn't enough). Choose **Associate**.
3. Check: the instance's **Details** tab shows the address under both **Elastic IP addresses** and **Public IPv4 address**. Neither step needs the instance stopped.
4. Note the address, for example `18.130.12.34`. Your HTTPS address is then **`https://18-130-12-34.sslip.io`**: the IP with dashes, plus `.sslip.io`, a free DNS name that points at the IP. With a real domain later, point an A record at the IP and use that name instead.

The live server: **35.178.64.255** (first deployed 25 Oct 2026 at https://35-178-64-255.sslip.io; on **magana.ng** since 25 Oct 2026).

## 6a. The domain (magana.ng)

> **Moving:** the website, www, app. and teachers. move to Cloudflare Pages (docs/DEPLOY_PAGES.md). This server keeps **api.magana.ng** (an A record, DNS only), plus the old sslip.io address for older APKs. The table below is the setup before the move.

DNS is on **Cloudflare, DNS only** (grey cloud, not proxied: Caddy needs the requests itself to get its certificates). Add four **A** records pointing at the Elastic IP, a **CNAME** `www` → `magana.ng` (Caddy redirects it to https://magana.ng), and no AAAA records:

| Name | Serves |
|---|---|
| `magana.ng` | the website, and the Android APK at `/downloads/magana.apk` |
| `api.magana.ng` | the API and the WhatsApp webhook |
| `app.magana.ng` | the tester PWA |
| `teachers.magana.ng` | the teacher portal, behind its login |

Check them with `dig +short A api.magana.ng @1.1.1.1`. Then set these in the server's `.env`:
```bash
MAGANA_DOMAIN=magana.ng
MAGANA_LEGACY_DOMAIN=35-178-64-255.sslip.io
MAGANA_CORS_ORIGIN_REGEX=https://(app|teachers)\.magana\.ng|https://35-178-64-255\.sslip\.io
```
Also set the GitHub variable `MAGANA_DOMAIN` to `magana.ng`. Caddy gets a certificate for each name on its first start.

**The old sslip.io address** keeps serving the API, without a redirect, so APKs built before 0.1.0+3 keep working. Its `/app` and `/teachers` paths redirect to the new subdomains. Once every tester has 0.1.0+3 or later, remove `MAGANA_LEGACY_DOMAIN` and its block in `deploy/Caddyfile`.

**The support address** is `support_email` in `config/public.json`. To switch it once the magana.ng support mailbox exists, run `python3 scripts/set_public_config.py support_email <the new address>`. That rewrites every copy: the app, portal, website and docs. `backend/tests/test_public_config.py` fails if any copy disagrees.

## 7. Set up the server (about 10 minutes)

```bash
ssh -i ~/.ssh/magana-london.pem ubuntu@18.130.12.34
curl -fsSL https://raw.githubusercontent.com/jemiridaniel/magana/main/deploy/setup-server.sh | bash
nano ~/srv/magana/.env
```

In `.env`, set:
- `MAGANA_DOMAIN=magana.ng` and `MAGANA_LEGACY_DOMAIN` (§6a). Without a domain, use the sslip.io name for both.
- `MAGANA_API_KEY=` and `IBA_API_KEY=`, each a different value from `openssl rand -hex 32`.

Keep the `MAGANA_API_KEY` value: the APK is built with it (`docs/TESTER_INSTALL.md`, "For the team"). Then:

```bash
cd ~/srv/magana && sudo docker compose -f docker-compose.prod.yml up -d --build
curl https://api.magana.ng/health
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
   scripts/aws-instance.sh start    # waits until https://api.magana.ng/health answers
   scripts/aws-instance.sh stop     # stop when nobody is testing, to save credit
   scripts/aws-instance.sh status
   scripts/deploy.sh                # pull the latest code on the server and rebuild
   ```

The containers restart by themselves when the instance starts (`restart: unless-stopped`).

## 8a. Automatic deploys from GitHub (CI/CD)

Every push runs the tests in GitHub Actions (`.github/workflows/ci.yml`: backend `pytest`, `flutter analyze`, `flutter test`, portal lint). On `main`, once they all pass, the `deploy` job:

1. Builds the PWA, the teacher portal and the website with **placeholders instead of keys**, and puts them on the `web-build` release (`magana-web.tar.gz`).
2. Signs in to AWS with **OIDC**: GitHub stores no AWS key, and only `main` of this repository can use the role.
3. Asks **Systems Manager** to run, on the instance, `git merge --ff-only <commit>` and then `deploy/update.sh`. It pulls Ibà, rebuilds, and waits for `/health`. **If health fails, it goes back to the previous commit.** Then it installs the PWA, portal and website, filling in the keys from the server's `.env`. GitHub doesn't need SSH, so port 22 stays limited to your IP.
4. Checks from outside: `https://api.magana.ng/health` answers, a call without the key gets 401, `https://app.magana.ng/` loads, and the portal asks for its login.

No server key is in GitHub. All of this is free: Systems Manager Run Command, IAM and OIDC cost nothing, and Actions is free for a public repository.

**One-time setup** (console, account "Magana"):

1. **IAM → Identity providers → Add provider → OpenID Connect.** Provider URL `https://token.actions.githubusercontent.com`, audience `sts.amazonaws.com`.
2. **IAM → Roles → Create role → Web identity.** Pick that provider and audience `sts.amazonaws.com`, then GitHub organization `jemiridaniel`, repository `magana`, branch `main`. Add no permissions, and name it `magana-github-deploy`. Then open the role and choose **Add permissions → Create inline policy → JSON** (fill in your account ID):
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {"Effect": "Allow", "Action": "ssm:SendCommand", "Resource": [
         "arn:aws:ec2:eu-west-2:<ACCOUNT_ID>:instance/i-0facf03cdaa771320",
         "arn:aws:ssm:eu-west-2::document/AWS-RunShellScript"]},
       {"Effect": "Allow", "Action": "ssm:GetCommandInvocation", "Resource": "*"}
     ]
   }
   ```
   Name it `magana-run-deploy`.

   Then **Trust relationships → Edit trust policy** (not a permissions policy: those refuse `Principal`). This repository uses GitHub's *immutable* subject, which carries the account and repo IDs, so the wizard's `repo:jemiridaniel/magana:…` never matches. Check the prefix with `gh api repos/jemiridaniel/magana/actions/oidc/customization/sub`:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Principal": {"Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"},
       "Action": "sts:AssumeRoleWithWebIdentity",
       "Condition": {"StringEquals": {
         "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
         "token.actions.githubusercontent.com:sub": "repo:jemiridaniel@94388185/magana@1431292597:ref:refs/heads/main"
       }}
     }]
   }
   ```
   The symptom of a wrong `sub` is "Not authorized to perform sts:AssumeRoleWithWebIdentity".
3. **IAM → Roles → Create role → AWS service → EC2**, with the policy `AmazonSSMManagedInstanceCore`. Name it `magana-ec2-ssm`. Then go to **EC2 → the instance → Actions → Security → Modify IAM role**, choose `magana-ec2-ssm` and click **Update**. The SSM agent is already on Ubuntu. Within a few minutes the instance appears in **Systems Manager → Fleet Manager**. The agent backs off after failing without a role: if the instance doesn't appear, reboot it (or run `sudo snap restart amazon-ssm-agent`).
4. Set the repository variables (variables, not secrets: none of them is a key):
   ```bash
   gh variable set AWS_DEPLOY_ROLE_ARN --body arn:aws:iam::<ACCOUNT_ID>:role/magana-github-deploy
   gh variable set MAGANA_INSTANCE_ID --body i-0facf03cdaa771320
   gh variable set MAGANA_DOMAIN --body magana.ng
   ```

The `deploy` job is skipped until `AWS_DEPLOY_ROLE_ARN` is set. First automatic deploy: 25 Oct 2026, about 1 minute on the server once the build finished. To watch a deploy, run `gh run watch`. `scripts/deploy.sh`, `deploy-web.sh` and `deploy-portal.sh` still work by hand from your Mac over SSH.

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

## 9a. Server speech (Whisper ASR, WhatsApp voices) and PaddleOCR: the instance plan

**Plan, not done yet.** It needs your go-ahead, because it uses about half the credit.

**What has to fit in memory:**

| | Memory | Measured? |
|---|---|---|
| What runs now (OS, Caddy, Ibà, backend) | 0.7 GB | yes, on the server |
| Whisper ASR, one language loaded, at its peak (transcribing plus the closed-set scoring) | 2.4 GB | yes, on a Mac |
| The WhatsApp voices: MMS English plus one of Hausa or Yorùbá, sharing torch with Whisper | about 0.5 GB more | yes, on a Mac (770 MB alone, of which torch is 300 MB) |
| PaddleOCR PP-StructureV3 | probably 2–3 GB | **no**: measure with `docker stats` after switching |
| **Total** | **about 5.6–6.6 GB** | |

**Instance: m7i-flex.large** (2 vCPU, 8 GiB). Of the free-plan types (t3.micro, t3.small, t4g.micro, t4g.small, c7i-flex.large, m7i-flex.large), it's the only one with enough memory. c7i-flex.large has 4 GiB, which is too little even without PaddleOCR (0.7 + 2.4 + 0.5 GB leaves no headroom for a reading). Only one Whisper language is loaded at a time (`asr.py`), so 8 GiB holds.

**Cost for 27 Nov to 20 Dec** (24 days, 576 hours, always on):

| | Cost |
|---|---|
| m7i-flex.large at $0.1107 an hour (London) | **$63.76** |
| The same weeks on the t3.small | $13.59 |
| **Extra for the switch** | **about $50** |
| Elastic IP ($2.88) and disk (about $2) | the same either way |
| Disk grown from 20 to 30 GiB for the models (do it first) | about $0.90 a month more |

- **The credit is tight:**
  - By 27 Nov, the t3.small, IP and disk will have used about $25 of the $100.
  - The 24 days on m7i-flex.large add about $69, which brings the total to about **$94 by 20 Dec**.
  - That leaves about $6, or roughly 3 weeks of the t3.small afterwards.
- **Stopping the instance outside testing hours** (for example 12 hours a day) halves the instance part, to about $32.
- **Prices:** from third-party pages ([aws-pricing.com](https://aws-pricing.com/m7i-flex.large.html), [devzero](https://www.devzero.io/instances/aws/m7i-flex.large)). Confirm in the AWS Pricing Calculator before switching. The free-plan types are from the [AWS EC2 Free Tier page](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html).

**Before (any day, about 5 minutes, no downtime): grow the disk.** Images and models need about 17 GB of the current 19.
1. **EC2 → Volumes →** the instance's volume **→ Modify → Size 30 → Modify.**
2. On the server: `sudo growpart /dev/nvme0n1 1 && sudo resize2fs /dev/nvme0n1p1 && df -h /`

A disk can grow but never shrink.

**Switch up (27 Nov, about 20 minutes, a few minutes offline):**
1. **EC2 → Instances → `magana-backend` → Instance state → Stop.** Wait for *Stopped*. The Elastic IP stays.
2. **Actions → Instance settings → Change instance type → `m7i-flex.large` → Apply.**
3. **Instance state → Start.** When `https://api.magana.ng/health` answers, SSH in:
   ```bash
   cd ~/srv/magana
   sed -i -e 's/^ASR_ENGINE=.*/ASR_ENGINE=local/' -e 's/^OCR_ENGINE=.*/OCR_ENGINE=paddle/' \
          -e 's/^WHATSAPP_VOICE=.*/WHATSAPP_VOICE=mms/' .env
   grep -q '^SPEECH=' .env && sed -i 's/^SPEECH=.*/SPEECH=on/' .env || echo 'SPEECH=on' >> .env
   sudo docker compose -f docker-compose.prod.yml up -d --build   # about 15 minutes, image about 5 GB bigger
   ```
   Change `.env` only **after** the type change: the next automatic deploy builds whatever `.env` says, and the t3.small can't build PaddleOCR and torch.
4. Check:
   - `/health`
   - `/asr/available`, which should now list the four languages
   - a test page read with `OCR_ENGINE=paddle` (the start-up self-test must pass)
   - a WhatsApp voice note
   - `sudo docker stats --no-stream` while reading and transcribing; write the memory down in FINDINGS.md

**Switch down (20 Dec):**
1. On the server, while it's still large (faster to build):
   ```bash
   cd ~/srv/magana
   sed -i -e 's/^ASR_ENGINE=.*/ASR_ENGINE=device/' -e 's/^OCR_ENGINE=.*/OCR_ENGINE=tesseract/' \
          -e 's/^WHATSAPP_VOICE=.*/WHATSAPP_VOICE=off/' -e 's/^SPEECH=.*/SPEECH=off/' .env
   sudo docker compose -f docker-compose.prod.yml up -d --build && sudo docker image prune -af
   ```
2. **Stop → Change instance type → `t3.small` →** check **Credit specification: Standard** **→ Start.**
3. Check `/health` and `free -m`. The speech models stay in the `hf_cache` volume for next time; `sudo docker volume rm magana_hf_cache` frees about 5 GB.

## 10. Explanations (N-ATLaS)

`EXPLAIN_ENGINE=stub` keeps Explain as a preview. To use a served N-ATLaS (docs/MODELS.md), set `EXPLAIN_ENGINE`, `EXPLAIN_URL` and `EXPLAIN_API_KEY` in `.env` and restart:

```bash
sudo docker compose -f docker-compose.prod.yml up -d
```

## 10a. The web app (PWA) at app.magana.ng

> **Moving to Cloudflare Pages** (docs/DEPLOY_PAGES.md). This section applies until the DNS change.

Every deploy rebuilds it (§8a). By hand: the same Caddy serves the Flutter web build at `https://app.magana.ng/` from `deploy/web/` on the server (git-ignored, mounted read-only into Caddy). From your Mac, with `MAGANA_API` and `MAGANA_API_KEY` in `~/.magana/app.env` and `MAGANA_HOST` in `~/.magana/aws.env`:

```bash
scripts/deploy-web.sh
```

It builds with `--base-href /`, fills in the service worker's file list and copies `build/web/` to the server. No restart is needed. `index.html`, `magana_sw.js`, `flutter_bootstrap.js` and `manifest.json` are served with `Cache-Control: no-cache`, so testers get the new version the next time they open it online.

**The web API key is public:** anyone can read it from the JavaScript. The backend therefore limits requests per IP and per device (`X-Magana-Device`), and answers `429 too_many_requests` with `Retry-After`. Defaults are per minute, in `.env`:

| Setting | Default | Applies to |
|---|---|---|
| `RATE_IP_PER_MIN` | 120 | every request from one IP |
| `RATE_DEVICE_PER_MIN` | 60 | every request from one device |
| `RATE_HEAVY_IP_PER_MIN` | 30 | `/read`, `/asr`, `/explain` from one IP |
| `RATE_HEAVY_DEVICE_PER_MIN` | 12 | the same, from one device |

A school's testers may share one IP behind a router. If they hit the limit, raise the two IP settings. `/health` is never limited. The limits are kept in memory, so a restart resets them.

## 10c. The teacher portal at teachers.magana.ng

> **Stays here, behind basic auth, until the portal's own sign-in ships;** then it moves to Cloudflare Pages too (docs/DEPLOY_PAGES.md, step 6).

Every deploy rebuilds it (§8a). By hand: the same Caddy serves the portal as static files at `https://teachers.magana.ng/`, behind a login (`PORTAL_USER` and `PORTAL_HASH` in `.env`), because its JavaScript carries the teacher key. From your Mac:

```bash
scripts/deploy-portal.sh
```

It reads the API and teacher keys from the server's `.env` over SSH, never printing them, builds the portal with `PORTAL_EXPORT=1`, copies it to `deploy/teachers/`, and deletes the local build. The login for teachers is in `~/.magana/portal-login.txt` on the deploying Mac. Share it privately, never in a group chat.

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

- **No HTTPS:** check that the security group allows 80 and 443, that each name's A record points at the Elastic IP (§6a), and `sudo docker compose -f docker-compose.prod.yml logs caddy`.
- **401 `bad_api_key` from the app:** the APK was built with a different `MAGANA_API_KEY`.
- **Out of memory on t3.small:** check swap (`swapon --show`). The setup script adds 2 GB.
