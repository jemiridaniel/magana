# The website, PWA and teacher portal on Cloudflare Pages

| Address | Where it runs | Built from |
|---|---|---|
| **magana.ng** (and www) | Cloudflare Pages, project `magana-website` | `website/` |
| **app.magana.ng** | Cloudflare Pages, project `magana-app` | `app/` (Flutter web) |
| **teachers.magana.ng** | Cloudflare Pages, project `magana-teachers`, once the portal has its own sign-in | `portal/` |
| **api.magana.ng** | The EC2 server, behind Caddy with Let's Encrypt (docs/DEPLOY_AWS.md) | `backend/` |
| 35-178-64-255.sslip.io | The EC2 server: the API only, for APKs older than 0.1.0+3 | `backend/` |

**Why:**
- Pages is free, and static files are served from Cloudflare's network, close to Nigerian users.
- The EC2 server only runs the API, so a stopped server never takes the website down.
- When the API is asleep, the PWA and the portal say so: "Magana's server is sleeping. Please try again later." (`server_sleeping`).

**How it deploys:** the `pages` job in `.github/workflows/ci.yml` runs on every push to `main` once all tests pass, beside the EC2 `deploy` job.
1. It builds each site.
2. It deploys with `wrangler pages deploy` (no Cloudflare Git integration needed, so the same tests guard both deploys).
3. It checks that `*.pages.dev` answers.
4. The website's APK comes from the public GitHub release `android-latest` (`scripts/publish-apk.sh`).

**Keys:**
- The PWA carries `MAGANA_WEB_API_KEY`, a separate key the backend accepts beside the APK's `MAGANA_API_KEY`. It is public in the page's JavaScript anyway, so the backend's rate limits protect it.
- It is a GitHub secret; the APK key never goes to GitHub.
- The portal gets no teacher key at all. Teachers sign in with their own accounts (HttpOnly cookie on api.magana.ng).

## Teacher portal sign-in: the portal's own login, not Cloudflare Access

The portal keeps a login. It will be **its own email sign-in** (a 6-digit code by email, HttpOnly cookie, invited emails only), not Cloudflare Access:
- **Magana needs real teacher accounts anyway.** Each teacher sees only their own classes, school admins manage teachers, and every change goes in an audit log. That needs the backend to know *which* teacher is asking. Access would only add a gate in front of a shared key.
- **One sign-in, not two.** With Access, teachers would first pass Cloudflare's email code, then still need a Magana account.
- **Access's free plan stops at 50 users.** A few schools would pass that.
- **Schools use any email** (Gmail, Yahoo, school domains). The portal's sign-in works with any address the school admin invites.

**Until that sign-in ships,** the portal stays on the EC2 server behind Caddy's basic auth. Setting the repository variable `PORTAL_ON_PAGES=true` moves it (step 6).

## One-time setup

### 1. A Cloudflare API token for GitHub (5 minutes)

1. Open **dash.cloudflare.com → My Profile → API Tokens → Create Token → Create Custom Token**.
2. Name: `magana-github-pages`.
3. Permissions: **Account → Cloudflare Pages → Edit**. Nothing else.
4. Account resources: **Include → your account**.
5. Choose **Continue to summary → Create Token**, and copy the token **once**.
6. In a terminal on your Mac (paste the token when asked; it never appears in chat or on screen):
   ```bash
   cd ~/Desktop/Personal\ Project/magana
   gh secret set CLOUDFLARE_API_TOKEN
   ```
7. Your **Account ID** is on the right of any zone's Overview page in the dashboard. It isn't a secret:
   ```bash
   gh variable set CLOUDFLARE_ACCOUNT_ID --body <account id>
   ```

### 2. The web key

On the server (it makes a new random key, then copies it into GitHub without printing it):

```bash
ssh -i ~/.ssh/magana-london.pem ubuntu@35.178.64.255 \
  'cd ~/srv/magana && (grep -q "^MAGANA_WEB_API_KEY=" .env || echo "MAGANA_WEB_API_KEY=$(openssl rand -hex 32)" >> .env) \
   && sudo docker compose -f docker-compose.prod.yml up -d'
ssh -i ~/.ssh/magana-london.pem ubuntu@35.178.64.255 \
  'grep -m1 "^MAGANA_WEB_API_KEY=" ~/srv/magana/.env | cut -d= -f2-' | gh secret set MAGANA_WEB_API_KEY
```

Also allow the Pages addresses in the server's CORS setting (`.env`):

```bash
MAGANA_CORS_ORIGIN_REGEX=https://(app|teachers)\.magana\.ng|https://([a-z0-9-]+\.)?magana-(app|teachers)\.pages\.dev|https://35-178-64-255\.sslip\.io
```

### 3. The first deploy

Push to `main` (or run `gh workflow run ci.yml --ref main`). The `pages` job creates the three projects and deploys the website and PWA. Check:
- https://magana-website.pages.dev
- https://magana-app.pages.dev (it talks to api.magana.ng)

### 4. The DNS changes, step by step

In **dash.cloudflare.com → magana.ng**:

1. **Keep the API on the server.** In **DNS → Records**, `api` stays an **A** record to `35.178.64.255`. Set it to **DNS only** (grey cloud): Caddy must answer Let's Encrypt itself.
2. **Delete** the A records for `@` (magana.ng), `app` and `teachers`, and the CNAME `www`. Pages refuses a custom domain that already has a record.
   - The website and PWA are offline from here until step 3 or 4 below, usually under a minute.
   - **Leave `teachers` alone** until step 6 if the portal isn't on Pages yet.
3. **Workers & Pages → `magana-website` → Custom domains → Set up a custom domain** → `magana.ng` → **Activate domain**. Cloudflare adds a proxied CNAME for it.
4. **`magana-app` → Custom domains** → `app.magana.ng` → **Activate domain**.
5. **www → magana.ng:**
   1. In **DNS → Records → Add record**, add a **CNAME** `www` → `magana.ng`, **Proxied** (orange).
   2. In **Rules → Redirect Rules → Create rule → "Redirect from WWW to root"** (a template), set **Custom filter**: hostname equals `www.magana.ng`.
   3. Then **Dynamic**: `concat("https://magana.ng", http.request.uri.path)`, status **301**, keep the query string. **Deploy**.
6. **Later, when the portal's own sign-in is live:**
   1. Run `gh variable set PORTAL_ON_PAGES --body true` and push.
   2. Delete the `teachers` A record.
   3. Add the custom domain `teachers.magana.ng` to `magana-teachers`.
7. **SSL/TLS → Overview: Full (strict).** api.magana.ng has its own Let's Encrypt certificate, and the Pages names get Cloudflare's.

**Check** with `dig +short magana.ng` (Cloudflare addresses now, not 35.178.64.255), then open each address. `curl -I https://www.magana.ng` should give `301` to `https://magana.ng/`.

### 5. Tidy the server (after the DNS change)

Once magana.ng, www and app no longer point at the server:
- remove their blocks from `deploy/Caddyfile`;
- remove the web bundle from the server deploy (`PORTAL_ON_PAGES=true` already stops it once the portal moves).

The sslip.io block stays, serving the API, until every tester has the new APK.

## Rolling back

Each Pages project keeps its deployments. Go to **Workers & Pages → project → Deployments →** an earlier one **→ Rollback**. That takes seconds and needs no rebuild.

To put a site back on the server instead:
1. Point its DNS record back to `35.178.64.255` as DNS only.
2. Restore its Caddy block.
3. Push.

## Cost

Pages' free plan has unlimited bandwidth and requests for static files, 500 builds a month (Magana builds on GitHub, not on Pages), and 20,000 files per site. The PWA has about 50 files, the website about 100, and the APK is one file of 21 MB, under Pages' 25 MiB per-file limit. If the APK ever grows past 25 MiB, the website will link to the GitHub release instead.
