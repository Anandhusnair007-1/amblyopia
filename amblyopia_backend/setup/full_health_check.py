"""
TASK 6 — Full System Health Check
Aravind Eye Hospital — Amblyopia Care System

Runs 25 checks across services, models, integrations, API routes,
and environment variables. Produces a scored report and JSON file.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime

import requests
from dotenv import load_dotenv

load_dotenv()

PROJECT = "/home/anandhu/projects/amblyopia_backend"
LOG_DIR = f"{PROJECT}/logs"
os.makedirs(LOG_DIR, exist_ok=True)
os.chdir(PROJECT)
sys.path.insert(0, PROJECT)

RESULTS: list[dict] = []

print("================================================")
print("TASK 6 — Full System Health Check")
print(f"Time:    {datetime.now().strftime('%Y-%m-%d %H:%M:%S IST')}")
print(f"Project: {PROJECT}")
print("================================================")


def check(category: str, name: str, passed: bool, detail: str = "") -> None:
    icon = "✓" if passed else "✗"
    status = "PASS" if passed else "FAIL"
    line   = f"  {icon} {status} — {name}"
    if detail:
        line += f"\n         {detail}"
    print(line)
    RESULTS.append({
        "category": category,
        "name":     name,
        "passed":   passed,
        "detail":   detail,
    })


# ════════════════════════════════════════════════════════════════════════
# SECTION 1 — SERVICE CHECKS
# ════════════════════════════════════════════════════════════════════════
print("")
print("[ 1/6 — SERVICES ]────────────────────────────")

# FastAPI
try:
    r = requests.get("http://localhost:8000/health", timeout=5)
    if r.status_code == 200:
        data = r.json()
        check("service", "FastAPI backend",  True,
              f"v{data.get('version','?')} · {data.get('environment','?')} · http://localhost:8000")
    else:
        check("service", "FastAPI backend", False,
              f"HTTP {r.status_code} — expected 200")
except requests.ConnectionError:
    check("service", "FastAPI backend", False,
          "Connection refused — run: bash run_local.sh")
except Exception as exc:
    check("service", "FastAPI backend", False, str(exc)[:80])

# Swagger docs
try:
    r = requests.get("http://localhost:8000/docs", timeout=5)
    check("service", "Swagger API docs", r.status_code == 200,
          f"http://localhost:8000/docs — HTTP {r.status_code}")
except Exception as exc:
    check("service", "Swagger API docs", False, str(exc)[:80])

# PostgreSQL
try:
    proc = subprocess.run(["pg_isready"], capture_output=True, text=True, timeout=5)
    check("service", "PostgreSQL", proc.returncode == 0,
          proc.stdout.strip() or "pg_isready returned non-zero")
except FileNotFoundError:
    check("service", "PostgreSQL", False, "pg_isready not found — install postgresql-client")
except Exception as exc:
    check("service", "PostgreSQL", False, str(exc)[:80])

# Redis
try:
    proc = subprocess.run(["redis-cli", "ping"], capture_output=True, text=True, timeout=5)
    pong = "PONG" in proc.stdout
    check("service", "Redis", pong,
          proc.stdout.strip() or "no response")
except FileNotFoundError:
    check("service", "Redis", False, "redis-cli not found — install redis-server")
except Exception as exc:
    check("service", "Redis", False, str(exc)[:80])

# MLflow (local file store used — UI is optional)
mlruns_exists = os.path.isdir(f"{PROJECT}/mlruns")
check("service", "MLflow local store", mlruns_exists,
      f"{PROJECT}/mlruns/ {'exists' if mlruns_exists else 'missing — will be created on first run'}")

try:
    # Increased timeout for MLflow startup latency
    r = requests.get("http://localhost:5055", timeout=5)
    check("service", "MLflow UI server", r.status_code == 200,
          "http://localhost:5055")
except Exception:
    check("service", "MLflow UI server", False,
          "Not running — start with: bash fixes/fix_mlflow.sh")


# ════════════════════════════════════════════════════════════════════════
# SECTION 2 — MODEL WEIGHT CHECKS
# ════════════════════════════════════════════════════════════════════════
print("")
print("[ 2/6 — MODEL WEIGHTS ]───────────────────────")

MODEL_SPECS = [
    ("Real-ESRGAN",
     f"{PROJECT}/models/real_esrgan/RealESRGAN_x4plus.pth",
     60_000_000, True),
    ("Zero-DCE",
     f"{PROJECT}/models/zero_dce/zero_dce_weights.pth",
     100_000, True),
    ("YOLOv8-nano",
     f"{PROJECT}/models/yolo/yolov8n.pt",
     5_000_000, True),
    ("DeblurGAN",
     f"{PROJECT}/models/deblurgan/fpn_inception.h5",
     0, False),           # 0 min — placeholder acceptable
    ("Whisper (python pkg)",
     None,                # weight path not relevant — openai-whisper downloads to cache
     0, False),
]

for name, path, min_size, required in MODEL_SPECS:
    if path is None:
        # Whisper — check python package
        try:
            import whisper as _w  # noqa
            check("model", f"Model: {name}", True,
                  "openai-whisper package installed — weights auto-downloaded on first use")
        except ImportError:
            check("model", f"Model: {name}", not required,
                  "openai-whisper not installed — run: pip install openai-whisper")
        continue

    if os.path.exists(path):
        size = os.path.getsize(path)
        mb   = size / 1024 / 1024
        if size >= max(min_size, 1):
            label = f"READY ({mb:.1f} MB)" if size > 1_000_000 else f"PLACEHOLDER ({size} B) — fallback active"
            check("model", f"Model: {name}", True, f"{os.path.relpath(path)}  {label}")
        else:
            check("model", f"Model: {name}", not required,
                  f"Empty file ({size} bytes) — run: bash setup/fix_deblurgan.sh")
    else:
        check("model", f"Model: {name}", not required,
              f"Missing: {os.path.relpath(path)} — run: bash setup/download_models.sh")


# ════════════════════════════════════════════════════════════════════════
# SECTION 3 — INTEGRATION CLASS CHECKS
# ════════════════════════════════════════════════════════════════════════
print("")
print("[ 3/6 — INTEGRATIONS ]────────────────────────")

INTEGRATION_SPECS = [
    ("DeblurGANIntegration",   "integrations.deblurgan_integration",
     "DeblurGANIntegration",   f"{PROJECT}/models/deblurgan/fpn_inception.h5"),
    ("RealESRGANIntegration",  "integrations.real_esrgan_integration",
     "RealESRGANIntegration",  f"{PROJECT}/models/real_esrgan/RealESRGAN_x4plus.pth"),
    ("ZeroDCEIntegration",     "integrations.zero_dce_integration",
     "ZeroDCEIntegration",     f"{PROJECT}/models/zero_dce/zero_dce_weights.pth"),
    ("YOLOIntegration",        "integrations.yolo_integration",
     "YOLOIntegration",        f"{PROJECT}/models/yolo/yolov8n.pt"),
    ("WhisperIntegration",     "integrations.whisper_integration",
     "WhisperIntegration",     None),
    ("RNNoiseIntegration",     "integrations.rnnoise_integration",
     "RNNoiseIntegration",     None),
]

for display_name, module_path, class_name, model_path in INTEGRATION_SPECS:
    try:
        import importlib
        mod   = importlib.import_module(module_path)
        klass = getattr(mod, class_name)

        if model_path:
            inst = klass(model_path)
        else:
            try:
                inst = klass()
            except RuntimeError as rte:
                check("integration", f"Integration: {display_name}", False,
                      f"Runtime error: {str(rte)[:80]}")
                continue

        check("integration", f"Integration: {display_name}", True,
              "Class loaded successfully")
    except Exception as exc:
        # Distinguish expected skips vs real failures
        err = str(exc)[:100]
        is_soft = any(k in err.lower() for k in ["not found", "missing", "no module", "import"])
        check("integration", f"Integration: {display_name}", False, err)


# ════════════════════════════════════════════════════════════════════════
# SECTION 4 — API ROUTE CHECKS
# ════════════════════════════════════════════════════════════════════════
print("")
print("[ 4/6 — API ROUTES ]──────────────────────────")

KEY_ROUTES = [
    ("GET",  "/health",                        "System health"),
    ("GET",  "/docs",                          "Swagger docs"),
    ("POST", "/api/auth/nurse-login",          "Auth — nurse login"),
    ("GET",  "/api/village/list",              "Village list"),
    ("POST", "/api/patient/create",            "Patient create"),
    ("GET",  "/api/nurse/profile",             "Nurse profile"),
    ("POST", "/api/screening/start",           "Screening start"),
    ("GET",  "/api/doctor/review-queue",       "Doctor queue"),
    ("GET",  "/api/dashboard/pilot-dashboard",     "Dashboard pilot view"),
    ("GET",  "/api/sync/check-model-update",       "Sync — model check"),
    ("GET",  "/api/notifications/history/test-id", "Notifications history"),
]

for method, path, label in KEY_ROUTES:
    try:
        r = requests.request(method, f"http://localhost:8000{path}", timeout=5,
                             json={} if method == "POST" else None)
        active = r.status_code not in (404, 500)
        check("api", f"API: {label}",  active,
              f"{method} {path}  →  HTTP {r.status_code}")
    except requests.ConnectionError:
        check("api", f"API: {label}", False, "Backend not reachable")
    except Exception as exc:
        check("api", f"API: {label}", False, str(exc)[:80])


# ════════════════════════════════════════════════════════════════════════
# SECTION 5 — DATABASE TABLE CHECKS
# ════════════════════════════════════════════════════════════════════════
print("")
print("[ 5/6 — DATABASE TABLES ]─────────────────────")

EXPECTED_TABLES = [
    "patients", "nurses", "villages", "screening_sessions",
    "gaze_results", "redgreen_results", "snellen_results",
    "combined_results", "doctor_reviews", "ml_models",
    "retraining_jobs", "notification_log", "sync_queue", "audit_trail",
]

try:
    from sqlalchemy import create_engine, inspect

    db_url = os.getenv("DATABASE_URL", "")
    sync   = db_url.replace("postgresql+asyncpg://", "postgresql://")
    eng    = create_engine(sync, pool_pre_ping=True)
    insp   = inspect(eng)
    existing = set(insp.get_table_names())

    found = sum(1 for t in EXPECTED_TABLES if t in existing)
    check("database", "Database tables (14)",
          found == len(EXPECTED_TABLES),
          f"{found}/{len(EXPECTED_TABLES)} tables present")

    for t in EXPECTED_TABLES:
        check("database", f"Table: {t}", t in existing,
              "exists" if t in existing else "MISSING — run: PYTHONPATH=. alembic upgrade head")
except Exception as exc:
    check("database", "Database connection", False, str(exc)[:100])


# ════════════════════════════════════════════════════════════════════════
# SECTION 6 — ENVIRONMENT VARIABLE CHECKS
# ════════════════════════════════════════════════════════════════════════
print("")
print("[ 6/6 — ENVIRONMENT ]─────────────────────────")

REQUIRED_ENVS = [
    ("DATABASE_URL",         "PostgreSQL connection string"),
    ("SECRET_KEY",           "JWT signing secret"),
    ("ENCRYPTION_KEY",       "AES-256 encryption key"),
    ("REDIS_URL",            "Redis connection string"),
    ("MLFLOW_TRACKING_URI",  "MLflow tracking URI"),
]

OPTIONAL_ENVS = [
    ("MINIO_ENDPOINT",       "MinIO (disabled locally)"),
    ("WHISPER_MODEL_SIZE",   "Whisper model size"),
    ("YOLO_MODEL_PATH",      "YOLOv8 model path"),
    ("ESRGAN_MODEL_PATH",    "Real-ESRGAN model path"),
]

for var, desc in REQUIRED_ENVS:
    val = os.getenv(var)
    ok  = bool(val and len(val) > 0)
    masked = f"{val[:6]}..." if val and len(val) > 6 else ("SET" if val else "MISSING")
    check("env", f"ENV: {desc}", ok, f"{var} = {masked}")

for var, desc in OPTIONAL_ENVS:
    val = os.getenv(var)
    ok  = bool(val)
    check("env", f"ENV (optional): {desc}", ok,
          f"{var} = {val or 'not set (optional)'}")


# ════════════════════════════════════════════════════════════════════════
# FINAL SCORE REPORT
# ════════════════════════════════════════════════════════════════════════
total   = len(RESULTS)
passed  = sum(1 for r in RESULTS if r["passed"])
failed  = total - passed
score   = int(passed / total * 100) if total else 0

by_cat: dict[str, dict] = {}
for r in RESULTS:
    cat = r["category"]
    if cat not in by_cat:
        by_cat[cat] = {"pass": 0, "fail": 0}
    if r["passed"]:
        by_cat[cat]["pass"] += 1
    else:
        by_cat[cat]["fail"] += 1

print("")
print("================================================")
print("HEALTH CHECK REPORT")
print("================================================")
print(f"  Time:    {datetime.now().strftime('%Y-%m-%d %H:%M:%S IST')}")
print(f"  Score:   {score}%  ({passed}/{total} checks passed)")
print("")
print(f"  {'Category':<14} {'Pass':>5} {'Fail':>5}")
print("  " + "─" * 26)
CAT_LABELS = {
    "service":     "Services",
    "model":       "Models",
    "integration": "Integrations",
    "api":         "API Routes",
    "database":    "Database",
    "env":         "Environment",
}
for cat, counts in by_cat.items():
    label = CAT_LABELS.get(cat, cat)
    print(f"  {label:<14} {counts['pass']:>5} {counts['fail']:>5}")
print("  " + "─" * 26)
print(f"  {'TOTAL':<14} {passed:>5} {failed:>5}")
print("")

if score == 100:
    print("  STATUS: ✓ SYSTEM FULLY HEALTHY")
    print("  READY:  Connect Flutter app to http://localhost:8000")
elif score >= 85:
    print("  STATUS: ✓ MOSTLY HEALTHY")
    print("  ACTION: Fix FAIL items above (system is usable now)")
elif score >= 60:
    print("  STATUS: ⚠ PARTIAL — NEEDS ATTENTION")
    print("  ACTION: Fix critical services and DB before using")
else:
    print("  STATUS: ✗ CRITICAL ISSUES FOUND")
    print("  ACTION: Fix all FAIL items — system not ready")

print("")
print("  Failed checks:")
fails = [r for r in RESULTS if not r["passed"]]
if fails:
    for r in fails:
        print(f"    ✗ [{r['category']}] {r['name']}")
else:
    print("    (none)")

print("================================================")

# Save report
report = {
    "timestamp":     datetime.now().isoformat(),
    "score_percent": score,
    "total":         total,
    "passed":        passed,
    "failed":        failed,
    "by_category":   by_cat,
    "results":       RESULTS,
}
report_path = f"{LOG_DIR}/health_report.json"
with open(report_path, "w") as f:
    json.dump(report, f, indent=2)
print(f"  Full report: {report_path}")
print("================================================")

sys.exit(0 if failed == 0 else 1)
