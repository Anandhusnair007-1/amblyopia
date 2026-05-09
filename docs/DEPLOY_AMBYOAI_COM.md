# Deploy AmbyoAI at **https://ambyoai.com** (Docker + nginx TLS)

This stack serves the React SPA and proxies **`/api`** to FastAPI on the same host name so the browser never mixes `http://` API with `https://` UI (a common cause of broken logins, blank screens, and camera failures).

## 1. DNS

Point **A** (and **AAAA** if you use IPv6) records for `ambyoai.com` and `www.ambyoai.com` to your server’s public IP.

## 2. TLS certificates (Let’s Encrypt)

On the server (from the repo root `amblyopia-main/`):

```bash
mkdir -p ssl/ambyoai.com certbot/www
```

**Option A — certbot standalone** (stop anything on port 80 first):

```bash
sudo certbot certonly --standalone -d ambyoai.com -d www.ambyoai.com
sudo cp /etc/letsencrypt/live/ambyoai.com/fullchain.pem ssl/ambyoai.com/
sudo cp /etc/letsencrypt/live/ambyoai.com/privkey.pem ssl/ambyoai.com/
sudo chmod 644 ssl/ambyoai.com/fullchain.pem
sudo chmod 640 ssl/ambyoai.com/privkey.pem
```

**Option B — HTTP-01 via nginx** (after you have any temporary cert so nginx can start, or use webroot while a simple HTTP server runs): place challenge files under `certbot/www/.well-known/acme-challenge/` and use `certbot certonly --webroot -w certbot/www …`. The production nginx config already exposes `/.well-known/acme-challenge/` from `/var/www/certbot` (mapped to `./certbot/www`).

Renewal: keep using certbot’s hooks to copy renewed PEMs into `ssl/ambyoai.com/` or change the compose volume mounts to point at `/etc/letsencrypt/live/...` directly (paths are stable symlinks on many systems).

## 3. Backend environment (`backend/.env`)

```bash
cp backend/.env.production.example backend/.env
```

Set at least:

| Variable | Example |
|----------|---------|
| `ENV` | `production` |
| `MONGO_URL` | `mongodb://mongo:27017` (compose network) or Atlas URI |
| `JWT_SECRET` | Long random (not the repo default) |
| `PII_ENCRYPTION_KEY` | Valid Fernet key |
| `PII_LOOKUP_SECRET` | Long random |
| `CORS_ORIGINS` | `https://ambyoai.com,https://www.ambyoai.com` |

Wrong or missing **`CORS_ORIGINS`** is the most frequent reason the UI “works locally” but **every API call fails** on the real domain (browser console shows CORS errors).

## 4. Frontend build

**Do not** bake `http://localhost:8001` into production. Leave **`REACT_APP_BACKEND_URL` empty** so the built app calls **`/api`** on `https://ambyoai.com` (same origin):

```bash
docker compose -f docker-compose.yml -f docker-compose.production.yml build --build-arg REACT_APP_BACKEND_URL= frontend
```

Default `docker compose build` already uses an empty URL when the arg is unset.

## 5. MongoDB exposure

The default `docker-compose.yml` publishes Mongo on `127.0.0.1:27017` for local dev. On a **public VPS**, comment out **`mongo: ports:`** so Mongo is only reachable inside the Docker network (or use Atlas instead).

## 6. Publish ports 80 / 443 on the VPS

Compose uses **environment substitution** (see repo root **`compose.env.example`**). Copy and edit:

```bash
cp compose.env.example .env
# Uncomment the FRONTEND_* VPS block in .env so HTTP/HTTPS listen on 0.0.0.0:80 and :443
```

Without this step, the stack still binds **127.0.0.1:8080** / **8443** only (local-dev defaults).

## 7. Start

```bash
docker compose -f docker-compose.yml -f docker-compose.production.yml up -d --build
```

**Assess** config + TLS + optional live health check:

```bash
bash scripts/assess_web_deploy.sh
```

Open **https://ambyoai.com** (not `http://` once TLS is live).

## 8. UI / camera checklist

| Symptom | Likely cause |
|--------|----------------|
| Network errors on `/api/...` | `CORS_ORIGINS` missing your `https://` origin |
| API calls go to `:8001` or wrong host | Frontend rebuilt with wrong `REACT_APP_BACKEND_URL`; rebuild with empty URL |
| Camera blocked | Must be **HTTPS** or **localhost**; real domain + valid TLS is OK |
| Old broken assets after deploy | Hard refresh or bump service worker cache in `public/sw.js` if you changed deploy URL |

## 9. Optional: temporary self-signed for `ambyoai.com`

If DNS works but you are waiting on Let’s Encrypt:

```bash
mkdir -p ssl/ambyoai.com
openssl req -x509 -nodes -days 30 -newkey rsa:2048 \
  -keyout ssl/ambyoai.com/privkey.pem \
  -out ssl/ambyoai.com/fullchain.pem \
  -subj "/CN=ambyoai.com" \
  -addext "subjectAltName=DNS:ambyoai.com,DNS:www.ambyoai.com"
```

Browsers will warn until you replace with real certificates.
