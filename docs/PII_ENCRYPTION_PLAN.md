# P1.1 — Application-level PII encryption

AmbyoAI stores pediatric screening data with **application-level encryption** for designated PII fields using **Fernet** (`cryptography`). Deterministic **HMAC-SHA256** indexes support lookup without storing plaintext phone or name in the database.

## Encrypted fields (at rest)

| Field | Notes |
|--------|--------|
| `name` | Patient full name |
| `phone` | 10-digit phone; queries use `phone_hash` |
| `date_of_birth` | ISO date string |
| `guardian_name` | Optional |
| `guardian_relation` | Optional |

**On-disk shape** (Fernet):

```json
{
  "enc": true,
  "alg": "fernet-v1",
  "ciphertext": "<urlsafe b64>",
  "key_version": "v1"
}
```

In **development**, if `PII_ENCRYPTION_KEY` is unset, a reversible **dev wrapper** is used (`enc: false`, `alg: dev-plaintext`). This must never be used in production.

## Fields not encrypted (and why)

| Field | Reason |
|--------|--------|
| `id` | Stable primary identifier (UUID); required for joins and auth subject |
| `age` | Derived from DOB for convenience; numeric, not direct identifier |
| `gender` | Low sensitivity; used in flows without decrypting DOB in some paths |
| `hospital_id`, `hospital_name` | Operational attribution |
| `test_results` / `details` | Clinical measurements and classifications for `classify_risk()` and doctor review — must remain queryable and comparable; already subject to patient-safe scrubbing in API policy |
| `last_risk_level`, session metadata | Operational / clinical workflow |
| AI prediction blobs | Doctor-facing; patient responses use sanitization policy, not DB encryption of numerics |

Encrypting clinical numerics would break risk scoring, auditing, and doctor dashboards without decrypting large graphs server-side.

## Lookup hash design

| Column | Algorithm | Input |
|--------|-----------|--------|
| `phone_hash` | HMAC-SHA256 (hex) | Normalized 10-digit phone string |
| `name_search_hash` (optional) | HMAC-SHA256 (hex) | Full name, lowercased, trimmed |

**Secret:** `PII_LOOKUP_SECRET` (dedicated; do not reuse `PII_ENCRYPTION_KEY`).

**Properties:**

- Deterministic: same phone → same hash (for login / OTP patient resolution).
- Not reversible without the secret.
- Does not replace encryption; it only enables equality lookup.

**Legacy:** Documents may still match via old `phone_hash` derivation (`legacy_jwt_phone_hash`) or plaintext `phone` during transition (`_find_patient_by_phone`).

## Key rotation plan

1. **Fernet (`PII_ENCRYPTION_KEY`)**  
   - Introduce `key_version` in ciphertext dict (already `v1`).  
   - For rotation: decrypt with old key, re-encrypt with new key, bump version (e.g. `v2`).  
   - Run a batch job similar to `scripts/migrate_encrypt_pii.py` with a read path that tries previous keys.  
   - Prefer **dual-read** (try new then old Fernet) during migration, then retire old key after all rows updated.

2. **Lookup secret (`PII_LOOKUP_SECRET`)**  
   - Changing it **invalidates all** `phone_hash` / `name_search_hash` values.  
   - Plan: backup collection → recompute hashes with new secret in a maintenance window → update indexes → decommission old secret.

3. **Operational**  
   - Store keys in a secrets manager (KMS / vault), not in git.  
   - Restrict production env access; log key IDs/versions, never key material.

## Migration process

Script: `backend/scripts/migrate_encrypt_pii.py`

1. Set `MONGO_URL`, `DB_NAME`, `PII_ENCRYPTION_KEY`, `PII_LOOKUP_SECRET` (and optional `JWT_SECRET`, `ENCRYPTION_KEY` for legacy reads).
2. **Dry-run (default):**  
   `cd backend && python3 scripts/migrate_encrypt_pii.py`  
   or explicitly:  
   `python3 scripts/migrate_encrypt_pii.py --dry-run`
3. Review output; confirm backup file path printed (JSON dump of `patients`).
4. **Apply:**  
   `python3 scripts/migrate_encrypt_pii.py --apply`

The script encrypts plaintext / legacy ciphertext fields, sets `phone_hash` and `name_search_hash` where needed, and stamps `pii_migrated_at` on apply.

## Limitations

- **Search:** Doctor search by name uses exact match on `name_search_hash` of the **full lowercased query**, not partial/substring search on ciphertext.
- **At-rest encryption** protects the database snapshot, not **in-memory** or **logs**: audit logs must not include decrypted PII (see implementation: failed OTP audits use `phone_hash`, not raw phone).
- **HMAC indexes** are vulnerable to **offline guessing** if the secret leaks; rate limits and network controls remain important.
- **Backups** of MongoDB remain sensitive if keys are co-located; use KMS and backup encryption.

## Production checklist

- [ ] `ENV=production`
- [ ] `PII_ENCRYPTION_KEY` set to a valid Fernet key; startup fails if missing
- [ ] `PII_LOOKUP_SECRET` set (strong, unique); startup fails if missing
- [ ] `JWT_SECRET` strong and separate from PII secrets
- [ ] `SENTRY_DSN` / logging reviewed so no PII in events
- [ ] Run migration `--dry-run`, then `--apply` after backup verification
- [ ] Verify patient OTP login, registration, doctor list, and consent flows
- [ ] Document key custody and rotation runbook for ops

## Related code

- `backend/security/crypto.py` — `encrypt_pii`, `decrypt_pii`, `hash_lookup`, `validate_pii_startup`
- `backend/server.py` — write paths, `serialize_patient`, `_find_patient_by_phone`, OTP / audit hygiene
- `backend/tests/test_pii_crypto.py` — unit coverage
