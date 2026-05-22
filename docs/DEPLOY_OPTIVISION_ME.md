# Deploy to **https://optivision.me**

| Item | Value |
|------|--------|
| Server | Azure VM `optivision-server` — `20.41.123.91` |
| SSH user | `azureuser` |
| App path | `/opt/ambyoai` |
| SSH key | `optivision-server_key.pem` in repo root (never commit) |

## One-command deploy (from your laptop)

```bash
cd ~/projects/amblyopia-push
chmod 600 optivision-server_key.pem
bash scripts/deploy_optivision.sh
```

This rsyncs code (excluding `backend/.env`, models, secrets) and runs:

```bash
docker compose -f docker-compose.yml -f docker-compose.optivision.production.yml up -d --build
```

TLS certs live on the host: `/etc/letsencrypt/live/optivision.me/`

## Manual SSH

```bash
ssh -i optivision-server_key.pem azureuser@20.41.123.91
cd /opt/ambyoai
docker compose -f docker-compose.yml -f docker-compose.optivision.production.yml ps
curl -fsS https://optivision.me/api/health
```

## backend/.env on server

Must include:

```
CORS_ORIGINS=https://optivision.me,https://www.optivision.me
MONGO_URL=mongodb://mongo:27017
```

Do **not** overwrite `backend/.env` during deploy (excluded from rsync).

## Verify after deploy

- https://optivision.me/ — patient/doctor UI loads
- https://optivision.me/api/health — `{"status":"ok"}`
