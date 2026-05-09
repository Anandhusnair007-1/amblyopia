# Host log folders (Docker)

Create these once (or let Docker create them on first `compose up`):

```bash
mkdir -p logs/mongo logs/backend logs/nginx logs/docker
```

| Path | Source |
|------|--------|
| `logs/mongo/mongod.log` | MongoDB (`--logpath` in `docker-compose.yml`) |
| `logs/backend/backend.log` | FastAPI / uvicorn app logger when `LOG_DIR=/app/logs` (set in Compose) |
| `logs/nginx/access_*.log`, `error_*.log` | Nginx (see `nginx.conf` / `nginx/ambyoai.com.conf`) |
| `logs/docker/*.log` | Optional snapshots from `scripts/save_stack_logs.sh` (stdout of all services) |

**Permissions:** If Mongo or Nginx fails to write, ensure the host directories are writable by the container user (e.g. `chmod 777 logs/mongo logs/nginx` for local dev only).

**One-off export** of everything Docker captured on stdout:

```bash
bash scripts/save_stack_logs.sh
```

Clinical audit events remain in MongoDB (`audit_logs`); these files are **server / proxy / database process** logs only.
