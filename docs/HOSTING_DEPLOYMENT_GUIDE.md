# AmbyoAI — hosting and deployment guide

Controlled pilot / demo only. AmbyoAI is **not** a substitute for professional diagnosis; AI outputs are **doctor-only**; patients receive patient-safe screening messaging only.

**Backend dependencies:** `emergentintegrations` was removed from `backend/requirements.txt` because it is not published on PyPI (it was only used in the Emergent preview environment). The core API does not import it, so `pip install -r requirements.txt` works in Docker and on normal servers.

## 1. Local Docker deployment

From the repository root (`amblyopia-main/`):

0. **Frontend local build** (optional sanity check before Docker):

   ```bash
   cd frontend
   corepack enable || true
   yarn install && yarn build
   ```

   If `yarn` is unavailable, use **`npm install --legacy-peer-deps`** then **`npm run build`** (same policy as `frontend/.npmrc`). Install MongoDB Database Tools on the host for backup scripts (`mongodump` / `mongorestore`).

1. **Backend environment**
   - `cp backend/.env.production.example backend/.env`
   - Edit `backend/.env`. For compose’s bundled MongoDB service, set:
     - `MONGO_URL=mongodb://mongo:27017`
     - All secrets (`JWT_SECRET`, `PII_ENCRYPTION_KEY`, `PII_LOOKUP_SECRET`) — generate strong values; never commit `backend/.env`.
   - Set `CORS_ORIGINS` to every exact UI origin (scheme + host + port), comma-separated, no spaces. Local Docker examples: `http://localhost:8080`, `https://localhost:8443`, `http://127.0.0.1:8080`.

2. **Frontend build-time API URL (Docker default)**
   - Default compose build uses an **empty** `REACT_APP_BACKEND_URL` so the SPA calls **same-origin `/api`**; nginx proxies `/api` to the backend (avoids **mixed content** if you open the UI over HTTPS).
   - To use a separate API host instead, rebuild with e.g. `REACT_APP_BACKEND_URL=https://api.example.com`.
   - ```bash
     docker compose build --build-arg REACT_APP_BACKEND_URL="https://api.example.com" frontend
     ```

3. **Run**
   ```bash
   docker compose up --build
   ```
   - **HTTP UI:** **http://localhost:8080** (or **http://127.0.0.1:8080** if Chrome upgrades `localhost` oddly).
   - **HTTPS UI (self-signed):** **https://localhost:8443** — first visit: **Advanced → Proceed to localhost** (local dev only).
   - **API (direct):** **http://localhost:8001** (optional; the SPA normally uses `/api` through nginx).
   - MongoDB (dev/demo): **127.0.0.1:27017** only — do not expose without TLS + auth.

### Chrome: `ERR_SSL_PROTOCOL_ERROR` on port 8080

Port **8080** serves **HTTP** only. If the address bar uses **`https://localhost:8080`** (or Chrome **HTTPS-First** tries TLS on that port), the TLS handshake hits an HTTP server → **`ERR_SSL_PROTOCOL_ERROR`**.

**Fix:** open **`http://localhost:8080`** (note **`http://`**) or use **`https://localhost:8443`** and accept the self-signed certificate once. To clear a bad **HSTS** entry for localhost: Chrome → `chrome://net-internals/#hsts` → Delete domain security policies for `localhost`.

4. **Models (AI)**
   - Model weights are gitignored. Mount models into the backend container or bake them in a private image; paths default under `backend/models/` (see `ai_engine.py` / env vars in `.env.production.example`).
   - Without models, AI endpoints may return **503** until weights are available.

5. **Production safety checks**
   - With `ENV=production`, startup **fails** if:
     - `JWT_SECRET` is missing or left at the repository default
     - `CORS_ORIGINS` is `*`
     - `PII_ENCRYPTION_KEY` / `PII_LOOKUP_SECRET` are missing or invalid (see `security/crypto.py`)

## 2. VPS deployment (outline)

1. **TLS**: Terminate HTTPS at **nginx**, **Caddy**, or **Traefik** in front of the frontend and API.
2. **Domains**: e.g. `app.example.com` → frontend static files or frontend container; `api.example.com` → reverse proxy to backend `:8001`.
3. **Environment**: Same variables as `backend/.env.production.example` on the server (secrets via vault or `.env` with strict permissions, **not** in git).
4. **Frontend**: Prefer **same-origin `/api`** (empty `REACT_APP_BACKEND_URL` + nginx proxy) to avoid mixed content and misconfigured API hosts. Use `REACT_APP_BACKEND_URL=https://api.example.com` only if the API is on a **separate** origin and CORS is set accordingly.
5. **MongoDB**: Prefer **MongoDB Atlas** or a hospital-hosted cluster with **authentication**, **TLS**, and network allowlists — not an open `27017` on the public internet.

### 2a. Single domain (e.g. **ambyoai.com**) with Docker + nginx HTTPS

See **[DEPLOY_AMBYOAI_COM.md](./DEPLOY_AMBYOAI_COM.md)** for DNS, Let’s Encrypt, `CORS_ORIGINS`, and:

```bash
docker compose -f docker-compose.yml -f docker-compose.production.yml up -d --build
```

Files: `nginx/ambyoai.com.conf`, `docker-compose.production.yml`, **`compose.env.example`** (copy to `.env` for public **80/443** binds), TLS PEMs under `ssl/ambyoai.com/` (gitignored). Run **`bash scripts/assess_web_deploy.sh`** to validate compose merge, TLS files, and optional `/api/health`.

## 3. Backend environment variables

See `backend/.env.production.example`. Critical groups:

| Area | Variables |
|------|-----------|
| Mode | `ENV`, `DATASET_VERSION` |
| Database | `MONGO_URL`, `DB_NAME` |
| Auth / JWT | `JWT_SECRET` |
| PII | `PII_ENCRYPTION_KEY`, `PII_LOOKUP_SECRET` |
| CORS | `CORS_ORIGINS` (comma-separated, no spaces) |
| Pilot safety | `ENABLE_DEMO_OTP`, `ENABLE_SEED_DOCTOR` |
| Rate limits | `OTP_RATE_LIMIT`, `LOGIN_RATE_LIMIT` |
| Monitoring | `SENTRY_DSN` (optional) |

`ENABLE_DEMO_OTP` and `ENABLE_SEED_DOCTOR` are forced safe when `ENV=production` in code, but set them explicitly in templates for clarity.

## 4. Frontend environment variables

See `frontend/.env.production.example`.

- **`REACT_APP_BACKEND_URL`**: Full base URL of the API **as seen by the browser** (scheme + host + port), no trailing slash. Create React App embeds this at **build time**.

## 5. MongoDB options

| Option | Use case |
|--------|----------|
| **Docker `mongo:7` (compose)** | Local pilot / dev only; bind to `127.0.0.1` as in `docker-compose.yml`. |
| **MongoDB Atlas** | Managed TLS + auth; restrict IP / VPC. |
| **Self-hosted** | Enable auth, TLS, backups; never expose unauthenticated Mongo to the internet. |

## 6. HTTPS / reverse proxy

- Enforce **HTTPS** for any browser-facing pilot over the internet.
- Forward `Authorization` and CORS preflight headers.
- Set `CORS_ORIGINS` to your real `https://app…` origin(s).
- Do not rely on wildcard `*` in production (startup will fail).

## 7. Production startup smoke test

On the server or laptop (with real secrets in the environment, **not** logged):

```bash
cd backend
export ENV=production
export MONGO_URL="mongodb://127.0.0.1:27017"   # or your URI
export DB_NAME=ambyoai
export JWT_SECRET='(long random)'
export PII_ENCRYPTION_KEY='(valid Fernet key)'
export PII_LOOKUP_SECRET='(long random)'
export CORS_ORIGINS=http://localhost:8080
export ENABLE_SEED_DOCTOR=false
python3 -m uvicorn server:app --host 0.0.0.0 --port 8001
```

Expect **failure** when misconfigured, for example:

```bash
ENV=production CORS_ORIGINS="*" python3 -m uvicorn server:app --host 0.0.0.0 --port 8001
```

Missing PII secrets should also fail fast in production.

## 8. PII migration before production

If the database predates PII encryption:

```bash
cd backend
source ../venv/bin/activate   # if used
python3 scripts/migrate_encrypt_pii.py --dry-run
python3 scripts/migrate_encrypt_pii.py --dry-run --verbose
python3 scripts/migrate_encrypt_pii.py --apply
```

Then verify in MongoDB: encrypted blobs for name / phone / DOB; `phone_hash` present; audit logs contain no raw phone/name (see pilot checklist).

## 9. Backup / restore checklist

- Install MongoDB database tools (`mongodump` / `mongorestore`) on a trusted admin machine with network access to Mongo.
- From repo root:
  ```bash
  chmod +x scripts/backup_mongodb.sh scripts/restore_mongodb.sh
  export MONGO_URL='...'
  export DB_NAME=ambyoai
  ./scripts/backup_mongodb.sh
  ```
  Or rely on `backend/.env` with `MONGO_URL` / `DB_NAME` set.
- Store archives **encrypted at rest**; treat them as **PHI**.
- Test restore on a **non-production** database before relying on it.

Restore (add `--drop` only if you intend to replace existing collections in the target DB):

```bash
./scripts/restore_mongodb.sh --yes /path/to/ambyoai_ambyoai_....archive.gz
# With collection drop (destructive):
./scripts/restore_mongodb.sh --yes --drop /path/to/....archive.gz
```

## 10. Verify flows after deploy

Use `docs/PILOT_HOSTING_CHECKLIST.md` for a structured pass: patient OTP/register/consent/tests, doctor dashboard and AI insights, admin/camp pages, audit logs, and “patient never sees deviation labels.”

## Useful Docker commands

```bash
# Build images only
docker compose build

# Backend logs
docker compose logs -f backend

# Shell into backend container
docker compose exec backend sh
```

## Repository layout for Docker

| File | Role |
|------|------|
| `Dockerfile.backend` | API image |
| `Dockerfile.frontend` | Build SPA + nginx |
| `docker-compose.yml` | mongo + backend + frontend |
| `nginx.conf` | SPA routing for frontend image |
| `.dockerignore` | Keeps secrets and large artifacts out of build context |
