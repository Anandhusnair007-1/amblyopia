# Key Rotation Policy — Amblyopia Care System

**Document ID:** DPDP-KRP-001  
**Version:** 1.0  
**Last Updated:** 2025  
**Owner:** Platform Engineering + Security Engineering  
**Review Frequency:** Annually or on compromise  

---

## 1. Cryptographic Key Inventory

| Key / Secret                | Type          | Algorithm      | TTL / Rotation | Storage         |
|-----------------------------|---------------|----------------|----------------|-----------------|
| `SECRET_KEY` (JWT signing)  | Symmetric     | HMAC-SHA256    | 90 days        | `.env` / secrets manager |
| `ENCRYPTION_KEY` (PII fields)| Symmetric    | AES-256-GCM    | 1 year         | `.env` / secrets manager |
| `BACKUP_ENCRYPTION_KEY`     | Symmetric     | AES-256-CBC    | 1 year         | `.env` / secrets manager |
| PostgreSQL password         | Credential    | bcrypt (stored)| 90 days        | `.env` / Docker secrets |
| Redis password              | Credential    | N/A            | 90 days        | `.env` / Docker secrets |
| MinIO / S3 access key       | API key       | AWS SigV4      | 90 days        | `.env` / IAM |
| TLS certificate (Nginx)     | X.509         | RSA 2048 / ECDSA P-256 | 90 days (Let's Encrypt) | Certbot auto-renew |
| JWT access tokens (user)    | Short-lived   | RS256 / HS256  | 24 hours       | In-memory (Redis revocation) |
| JWT refresh tokens (user)   | Medium-lived  | HS256          | 7 days         | Client only |
| GitHub Actions secrets      | Credential    | N/A            | 180 days       | GitHub Secrets |
| cosign keyless OIDC         | Ephemeral     | ECDSA P-256    | Per-signing    | Sigstore / Fulcio |

---

## 2. Rotation Procedures

### 2.1 `SECRET_KEY` — JWT Signing Key (every 90 days)

**Impact:** All existing JWTs become invalid at rotation → users must re-login.  
**Recommended approach:** Dual-key overlap (accept old key for 1h, issue only new key).

```bash
# Step 1: Generate new key
NEW_KEY=$(python -c "import secrets; print(secrets.token_hex(32))")
echo "New SECRET_KEY: $NEW_KEY"

# Step 2: Update .env (or update secrets manager)
sed -i "s/^SECRET_KEY=.*/SECRET_KEY=${NEW_KEY}/" .env

# Step 3: Graceful restart (zero-downtime)
docker-compose -f docker/docker-compose.prod.yml up -d --no-deps backend

# Step 4: Log rotation in audit trail
echo "$(date): SECRET_KEY rotated by $(whoami)" >> /var/log/amblyopia/key_rotations.log
```

---

### 2.2 `ENCRYPTION_KEY` — PII Column Encryption (every 1 year)

**Impact:** Must re-encrypt all PII columns in database during rotation.  
**This is a maintenance window operation.**

```bash
# Step 1: Generate new 32-byte key
NEW_ENC_KEY=$(python -c "import secrets; print(secrets.token_hex(32))")

# Step 2: Run re-encryption migration script
python -m app.utils.reencrypt_pii \
    --old-key "$ENCRYPTION_KEY" \
    --new-key "$NEW_ENC_KEY"

# Step 3: Verify random sample of records decrypt correctly
python -m app.utils.verify_pii_sample --key "$NEW_ENC_KEY"

# Step 4: Update secret and restart
sed -i "s/^ENCRYPTION_KEY=.*/ENCRYPTION_KEY=${NEW_ENC_KEY}/" .env
docker-compose -f docker/docker-compose.prod.yml up -d --no-deps backend
```

---

### 2.3 Database & Redis Credentials (every 90 days)

```bash
# 1. Generate new password
NEW_PG_PW=$(python -c "import secrets; print(secrets.token_urlsafe(24))")

# 2. Update PostgreSQL
PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U amblyopia -d amblyopia_db \
  -c "ALTER USER amblyopia WITH PASSWORD '${NEW_PG_PW}';"

# 3. Update .env
sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${NEW_PG_PW}/" .env

# 4. Restart backend
docker-compose -f docker/docker-compose.prod.yml up -d --no-deps backend
```

---

### 2.4 TLS Certificate (automatic — Let's Encrypt, 90-day certificates)

Certbot auto-renews at 60 days. Verify cron/timer is active:

```bash
# Verify certbot timer (systemd)
systemctl status certbot.timer

# Manual renewal test
certbot renew --dry-run

# Force renewal
certbot renew --force-renewal
nginx -s reload
```

---

### 2.5 S3 / MinIO Access Keys (every 90 days)

```bash
# AWS IAM: create new access key, update .env, then delete old key
aws iam create-access-key --user-name amblyopia-backup > /tmp/new_key.json
NEW_ACCESS=$(jq -r '.AccessKey.AccessKeyId' /tmp/new_key.json)
NEW_SECRET=$(jq -r '.AccessKey.SecretAccessKey' /tmp/new_key.json)

# Update .env
sed -i "s/^AWS_ACCESS_KEY_ID=.*/AWS_ACCESS_KEY_ID=${NEW_ACCESS}/" .env
sed -i "s/^AWS_SECRET_ACCESS_KEY=.*/AWS_SECRET_ACCESS_KEY=${NEW_SECRET}/" .env

# Restart affected services
docker-compose -f docker/docker-compose.prod.yml up -d --no-deps backend

# Revoke old key (60 min after restart to avoid in-flight requests)
sleep 3600
aws iam delete-access-key --user-name amblyopia-backup --access-key-id "$OLD_ACCESS_KEY"
```

---

## 3. Emergency Key Rotation (On Compromise)

If a key is confirmed or suspected compromised:

1. **Immediately** generate new key and deploy (accept impact of forced re-login)
2. Revoke / delete old key with no overlap period
3. Audit all operations performed with the compromised key (query `audit_logs`, S3 access logs)
4. Classify as security incident (follow `incident_response.md`)
5. Notify DPO if PII was potentially exposed during compromise window

---

## 4. Key Storage Requirements

| Requirement | Implementation |
|-------------|---------------|
| Never commit keys to Git | `.gitignore` covers `.env`; gitleaks scans all commits |
| No keys in Docker images | Build args for metadata only; secrets via runtime env |
| Encrypted at rest | Secrets manager or encrypted `.env` on disk |
| Access logging | All secret accesses logged in secrets manager audit trail |
| Backup copies | Keys stored in secure password manager (Bitwarden / HashiCorp Vault) |

---

## 5. Rotation Calendar Template

| Month | Key Rotation Due |
|-------|-----------------|
| Jan   | SECRET_KEY, DB password, S3 keys |
| Apr   | SECRET_KEY, DB password, S3 keys |
| Jul   | SECRET_KEY, DB password, S3 keys, ENCRYPTION_KEY |
| Oct   | SECRET_KEY, DB password, S3 keys |
| TLS   | Ongoing (Let's Encrypt auto-renew every 60 days) |
