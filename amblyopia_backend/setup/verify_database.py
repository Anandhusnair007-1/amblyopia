"""
TASK 5 — Verify All 14 Database Tables
Aravind Eye Hospital — Amblyopia Care System

Connects to local PostgreSQL, checks every table exists,
counts rows, reports column counts. Runs Alembic if tables missing.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime

from dotenv import load_dotenv

load_dotenv()

PROJECT    = "/home/anandhu/projects/amblyopia_backend"
LOG_DIR    = f"{PROJECT}/logs"
os.makedirs(LOG_DIR, exist_ok=True)
os.chdir(PROJECT)

print("================================================")
print("TASK 5 — Verifying All 14 Database Tables")
print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S IST')}")
print("================================================")
print("")

# ── Read DATABASE_URL ─────────────────────────────────────────────────────────
DATABASE_URL = os.getenv("DATABASE_URL", "")
if not DATABASE_URL:
    print("ERROR: DATABASE_URL not set — check .env file")
    sys.exit(1)

SYNC_URL = (
    DATABASE_URL
    .replace("postgresql+asyncpg://", "postgresql://")
    .replace("postgresql+aiopg://",   "postgresql://")
)
host_part = DATABASE_URL.split("@")[-1] if "@" in DATABASE_URL else DATABASE_URL
print(f"Database: {host_part}")
print("")

# ── Connect ───────────────────────────────────────────────────────────────────
try:
    from sqlalchemy import create_engine, inspect, text
except ImportError:
    print("ERROR: sqlalchemy not installed — run: pip install sqlalchemy psycopg2-binary")
    sys.exit(1)

try:
    engine = create_engine(SYNC_URL, pool_pre_ping=True)
    with engine.connect() as conn:
        version_row = conn.execute(text("SELECT version()")).fetchone()
        pg_version  = version_row[0].split(",")[0] if version_row else "unknown"
        print(f"PostgreSQL: {pg_version}")
        print("")
except Exception as exc:
    print(f"ERROR: Cannot connect to database — {exc}")
    print("")
    print("Troubleshooting:")
    print("  1. Is PostgreSQL running?  →  sudo systemctl start postgresql")
    print("  2. Does user exist?        →  sudo -u postgres psql -c \"CREATE USER amblyopia_user WITH PASSWORD 'amblyopia_pass';\"")
    print("  3. Does DB exist?          →  sudo -u postgres psql -c \"CREATE DATABASE amblyopia_db OWNER amblyopia_user;\"")
    sys.exit(1)

# ── Expected tables ───────────────────────────────────────────────────────────
EXPECTED_TABLES = [
    ("patients",            "Core patient anonymised records"),
    ("nurses",              "Nurse accounts and credentials"),
    ("villages",            "Village geo + demographic data"),
    ("screening_sessions",  "Per-visit screening session"),
    ("gaze_results",        "Gaze tracking results"),
    ("redgreen_results",    "Pupil / red-green test results"),
    ("snellen_results",     "Snellen visual acuity results"),
    ("combined_results",    "AI-combined risk score per session"),
    ("doctor_reviews",      "Doctor review and override records"),
    ("ml_models",           "Model version registry"),
    ("retraining_jobs",     "Airflow retraining job log"),
    ("notification_log",    "WhatsApp / SMS notification log"),
    ("sync_queue",          "Offline session sync queue"),
    ("audit_trail",         "DPDP Act compliance audit log"),
]

# ── Inspect existing tables ───────────────────────────────────────────────────
try:
    inspector = inspect(engine)
    existing  = set(inspector.get_table_names())
except Exception as exc:
    print(f"ERROR: Cannot inspect database — {exc}")
    sys.exit(1)

print("Table Status:")
print(f"{'Table':<25} {'Status':<10} {'Cols':>4}  Description")
print("─" * 72)

found   = 0
missing = []

for table_name, description in EXPECTED_TABLES:
    if table_name in existing:
        try:
            cols = len(inspector.get_columns(table_name))
        except Exception:
            cols = 0
        print(f"  {'✓':<1}  {table_name:<23} {'FOUND':<10} {cols:>4}  {description}")
        found += 1
    else:
        print(f"  {'✗':<1}  {table_name:<23} {'MISSING':<10} {'—':>4}  {description}")
        missing.append(table_name)

print("─" * 72)
print(f"  Found: {found}/14   Missing: {len(missing)}/14")
print("")

# ── Auto-run migrations if tables are missing ────────────────────────────────
if missing:
    print(f"Missing tables: {', '.join(missing)}")
    print("")
    print("Running Alembic migrations to create missing tables...")
    print("")
    result = subprocess.run(
        ["bash", "-c", f"cd {PROJECT} && source venv/bin/activate && PYTHONPATH={PROJECT} alembic upgrade head"],
        capture_output=True, text=True
    )
    print(result.stdout)
    if result.stderr:
        print(result.stderr)

    if result.returncode == 0:
        print("Migrations complete. Re-checking tables...")
        print("")
        inspector     = inspect(engine)   # refresh
        existing      = set(inspector.get_table_names())
        found_after   = sum(1 for t, _ in EXPECTED_TABLES if t in existing)
        still_missing = [t for t, _ in EXPECTED_TABLES if t not in existing]

        print(f"After migration: {found_after}/14 tables found")
        if still_missing:
            print(f"Still missing: {', '.join(still_missing)}")
            print("Check migrations/versions/ for missing migration files")
        else:
            print("All 14 tables now present ✓")
    else:
        print("Migration failed — check error above")
        print(f"Manual fix: PYTHONPATH={PROJECT} alembic upgrade head")
else:
    # ── Row counts ────────────────────────────────────────────────────────────
    print("Row Counts (current data):")
    print(f"{'Table':<25} {'Rows':>8}")
    print("─" * 36)

    total_rows = 0
    row_data   = {}
    with engine.connect() as conn:
        for table_name, _ in EXPECTED_TABLES:
            if table_name in existing:
                try:
                    row = conn.execute(text(f"SELECT COUNT(*) FROM {table_name}")).fetchone()
                    count = int(row[0]) if row else 0
                except Exception:
                    count = -1
                row_data[table_name] = count
                total_rows += max(0, count)
                print(f"  {table_name:<25} {count:>8}")

    print("─" * 36)
    print(f"  {'TOTAL ROWS':<25} {total_rows:>8}")
    print("")

# ── Final status ──────────────────────────────────────────────────────────────
inspector = inspect(engine)
existing  = set(inspector.get_table_names())
found     = sum(1 for t, _ in EXPECTED_TABLES if t in existing)

print("================================================")
if found == 14:
    print("STATUS:  ✓ ALL 14 TABLES PRESENT")
    print("         Database schema is complete.")
else:
    print(f"STATUS:  ✗ {14 - found} TABLE(S) MISSING")
    print("         Run: PYTHONPATH=. alembic upgrade head")
print("================================================")

# ── Save report ───────────────────────────────────────────────────────────────
report = {
    "timestamp":      datetime.now().isoformat(),
    "database":       host_part,
    "expected":       14,
    "found":          found,
    "missing":        [t for t, _ in EXPECTED_TABLES if t not in existing],
    "table_details":  [
        {
            "name":        t,
            "exists":      t in existing,
            "description": d,
        }
        for t, d in EXPECTED_TABLES
    ],
}
report_path = f"{LOG_DIR}/db_verification_report.json"
with open(report_path, "w") as f:
    json.dump(report, f, indent=2)
print(f"Report saved: {report_path}")
print("================================================")
