#!/usr/bin/env python3
"""
Migrate patient PII fields to structured encryption + HMAC hashes.

  python3 scripts/migrate_encrypt_pii.py           # dry-run (default)
  python3 scripts/migrate_encrypt_pii.py --apply   # write MongoDB

Requires env: MONGO_URL, DB_NAME, PII_ENCRYPTION_KEY, PII_LOOKUP_SECRET
Optional: JWT_SECRET (to recognize legacy phone_hash), ENCRYPTION_KEY (legacy Fernet)
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")
sys.path.insert(0, str(ROOT))

from bson import json_util  # type: ignore
from pymongo import MongoClient

from security.crypto import decrypt_pii, encrypt_pii, hash_lookup


def _already_new(blob) -> bool:
    return isinstance(blob, dict) and blob.get("enc") is True and blob.get("alg") == "fernet-v1"


PII_FIELDS = ("name", "phone", "date_of_birth", "guardian_name", "guardian_relation")


def _is_production_encrypted(blob) -> bool:
    return isinstance(blob, dict) and blob.get("enc") is True and blob.get("alg") == "fernet-v1"


def patient_has_plaintext_or_legacy_pii(doc: dict) -> bool:
    """True if any non-empty PII field is not structured Fernet-v1."""
    for k in PII_FIELDS:
        v = doc.get(k)
        if v is None or v == "":
            continue
        if not _is_production_encrypted(v):
            return True
    return False


def patient_all_pii_fields_fernet(doc: dict) -> bool:
    """True if every non-empty PII field is fernet-v1 (crypto shape OK)."""
    for k in PII_FIELDS:
        v = doc.get(k)
        if v is None or v == "":
            continue
        if not _is_production_encrypted(v):
            return False
    return True


def _plain_phone_for_hash(doc: dict) -> str:
    ph = doc.get("phone")
    if isinstance(ph, str) and ph.isdigit() and len(ph) == 10:
        return ph
    return (decrypt_pii(ph) or "").strip()


def patient_missing_or_wrong_phone_hash(doc: dict, jwt_secret: str | None) -> bool:
    plain = _plain_phone_for_hash(doc)
    if len(plain) != 10:
        return False
    new_h = hash_lookup(plain)
    legacy_h = None
    if jwt_secret:
        legacy_h = hashlib.sha256(f"{jwt_secret}_{plain}".encode()).hexdigest()
    cur = doc.get("phone_hash")
    if not cur:
        return True
    if cur == new_h or (legacy_h and cur == legacy_h):
        return False
    return True


def migrate_patient(doc: dict, jwt_secret: str | None) -> dict | None:
    updates: dict = {}

    # name
    n = doc.get("name")
    if n is not None and not _already_new(n):
        plain = decrypt_pii(n)
        if plain:
            updates["name"] = encrypt_pii(plain)
            updates["name_search_hash"] = hash_lookup(plain.strip().lower())

    # phone
    ph = doc.get("phone")
    if ph is not None and not _already_new(ph):
        plain = decrypt_pii(ph)
        if plain:
            updates["phone"] = encrypt_pii(plain)

    phone_plain = decrypt_pii(doc.get("phone")) or ""
    if isinstance(doc.get("phone"), str) and doc["phone"].isdigit() and len(doc["phone"]) == 10:
        phone_plain = doc["phone"]
    if phone_plain:
        new_h = hash_lookup(phone_plain)
        legacy_h = None
        if jwt_secret:
            legacy_h = hashlib.sha256(f"{jwt_secret}_{phone_plain}".encode()).hexdigest()
        cur = doc.get("phone_hash")
        if cur != new_h and cur != legacy_h:
            updates["phone_hash"] = new_h
        elif not cur:
            updates["phone_hash"] = new_h

    # date_of_birth
    dob = doc.get("date_of_birth")
    if dob is not None and not _already_new(dob):
        plain = decrypt_pii(dob)
        if isinstance(dob, str) and len(dob) <= 12 and dob.count("-") >= 2:
            plain = dob
        if plain:
            updates["date_of_birth"] = encrypt_pii(plain)

    # guardian_name
    g = doc.get("guardian_name")
    if g is not None and not _already_new(g):
        plain = decrypt_pii(g)
        if plain:
            updates["guardian_name"] = encrypt_pii(plain)

    # guardian_relation
    gr = doc.get("guardian_relation")
    if gr is not None and not _already_new(gr):
        plain = decrypt_pii(gr)
        if isinstance(gr, str) and plain is None:
            plain = gr
        if plain:
            updates["guardian_relation"] = encrypt_pii(plain)

    if not updates:
        return None
    return updates


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Dry-run by default; pass --apply to write MongoDB.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report changes without writing (default when --apply is omitted)",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Apply updates to MongoDB",
    )
    parser.add_argument("--backup", default="patients_backup_pre_pii.json")
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print one line per patient that would be updated",
    )
    args = parser.parse_args()
    if args.apply and args.dry_run:
        parser.error("Use either --apply or --dry-run, not both")
    write = args.apply

    for k in ("MONGO_URL", "DB_NAME", "PII_ENCRYPTION_KEY", "PII_LOOKUP_SECRET"):
        if not os.environ.get(k):
            print(f"ERROR: missing {k}", file=sys.stderr)
            sys.exit(1)

    jwt_secret = os.environ.get("JWT_SECRET")
    mongo_url = os.environ["MONGO_URL"]
    try:
        client = MongoClient(
            mongo_url,
            serverSelectionTimeoutMS=8000,
            connectTimeoutMS=8000,
        )
        client.admin.command("ping")
    except Exception as e:
        print(
            f"ERROR: cannot connect to MongoDB ({mongo_url}): {e}\n"
            "Start MongoDB (e.g. docker run -d -p 27017:27017 mongo:7) and retry.",
            file=sys.stderr,
        )
        sys.exit(2)
    coll = client[os.environ["DB_NAME"]]["patients"]
    rows = list(coll.find({}, {"_id": 0}))

    bp = Path(args.backup)
    bp.write_text(json_util.dumps(rows, indent=2), encoding="utf-8")
    print(f"Backup {len(rows)} patients -> {bp.resolve()}")

    total = len(rows)
    plaintext_pii = sum(1 for d in rows if patient_has_plaintext_or_legacy_pii(d))
    all_fernet_shape = sum(1 for d in rows if patient_all_pii_fields_fernet(d))
    missing_phone_hash = sum(1 for d in rows if patient_missing_or_wrong_phone_hash(d, jwt_secret))
    already_no_action = 0
    n = 0
    for doc in rows:
        upd = migrate_patient(doc, jwt_secret)
        if not upd:
            already_no_action += 1
            continue
        n += 1
        if args.verbose:
            print(f"{'APPLY' if write else 'DRY-RUN'} {doc['id']}: {list(upd.keys())}")
        if write:
            upd["pii_migrated_at"] = datetime.now(timezone.utc).isoformat()
            coll.update_one({"id": doc["id"]}, {"$set": upd})

    print()
    print("=== SUMMARY ===")
    print(f"total_patients:              {total}")
    print(f"plaintext_or_legacy_pii:     {plaintext_pii}  (any name/phone/DOB/guardian not fernet-v1)")
    print(f"all_pii_fields_fernet_v1:    {all_fernet_shape}  (non-empty PII fields only; shape check)")
    print(f"missing_or_wrong_phone_hash: {missing_phone_hash}  (10-digit phone resolvable)")
    print(f"already_no_migration_needed: {already_no_action}")
    print(f"would_update / updated:      {n}")
    print(f"backup_path:                 {bp.resolve()}")
    print(f"mode:                        {'APPLY' if write else 'DRY-RUN'}")
    if not args.verbose and n:
        print("(Re-run with --verbose to list each patient id and updated keys.)")


if __name__ == "__main__":
    main()
