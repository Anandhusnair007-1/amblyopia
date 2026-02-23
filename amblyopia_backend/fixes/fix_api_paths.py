#!/usr/bin/env python3
"""
FIX 3 — Correcting API paths and testing all
============================================
Fetches real OpenAPI schema, maps wrong paths to correct ones,
and tests every single route for connectivity.
"""
import requests
import json
import os
from datetime import datetime

BASE = "http://localhost:8000"
LOG_DIR = "/home/anandhu/projects/amblyopia_backend/logs"
os.makedirs(LOG_DIR, exist_ok=True)

print("============================================")
print("FIX 3 — Correcting API paths and testing all")
print("============================================")
print(f"Time: {datetime.now().strftime('%H:%M:%S')}")
print("")

# Step 1: Get real OpenAPI schema
print("Fetching real API schema...")
try:
    r = requests.get(f"{BASE}/openapi.json", timeout=5)
    r.raise_for_status()
    schema = r.json()
    real_paths = list(schema.get("paths", {}).keys())
    print(f"Found {len(real_paths)} real API routes")
except Exception as e:
    print(f"Cannot reach backend: {e}")
    print("Run: bash run_local.sh first")
    exit(1)

print("")
print("ALL REAL API ROUTES:")
print("-" * 50)
for path in sorted(real_paths):
    print(f"  {path}")

print("")
print("-" * 50)

# Step 2: Fix wrong path mappings
wrong_to_correct = {
    "/api/dashboard/village-heatmap":
        "/api/dashboard/pilot-dashboard",
    "/api/sync/pending-model-update":
        "/api/sync/check-model-update",
    "/api/notifications/unread-count":
        "/api/notifications/history/test-id",
}

print("PATH CORRECTIONS:")
print("-" * 50)
for wrong, correct in wrong_to_correct.items():
    check_path = correct.split("{")[0].rstrip("/") if "{" in correct else correct
    if any(p.startswith(check_path) for p in real_paths):
        print(f"FIXED:  {wrong}")
        print(f"    →   {correct}")
    else:
        # Search for similar path
        similar = [p for p in real_paths
                   if any(part in p for part
                   in wrong.split("/") if len(part) > 3)]
        if similar:
            print(f"WRONG:  {wrong}")
            print(f"MAYBE:  {similar[0]}")
        else:
            print(f"WRONG:  {wrong}")
            print(f"CHECK:  Not found in schema")
    print("")

# Step 3: Test all real routes
print("")
print("TESTING ALL REAL ROUTES:")
print("-" * 50)

results = {}
skip_patterns = ["{", "download"]

for path in sorted(real_paths):
    # Skip routes with path params for now
    if any(p in path for p in skip_patterns):
        results[path] = "SKIP (has path param)"
        print(f"SKIP  — {path}")
        continue
    
    try:
        r = requests.get(
            f"{BASE}{path}",
            timeout=5
        )
        # 200=ok 401=auth needed 403=forbidden
        # 405=wrong method — all mean route EXISTS
        if r.status_code in [200, 401, 403, 405, 422]:
            results[path] = f"ACTIVE ({r.status_code})"
            print(f"ACTIVE — {path} [{r.status_code}]")
        elif r.status_code == 404:
            results[path] = "NOT FOUND (404)"
            print(f"404    — {path}")
        else:
            results[path] = f"STATUS {r.status_code}"
            print(f"OTHER  — {path} [{r.status_code}]")
    except Exception as e:
        results[path] = f"ERROR: {e}"
        print(f"ERROR  — {path}")

# Step 4: Summary
active = sum(1 for v in results.values()
             if "ACTIVE" in v)
not_found = sum(1 for v in results.values()
                if "404" in v)
skipped = sum(1 for v in results.values()
              if "SKIP" in v)

print("")
print("============================================")
print("CORRECTED API ROUTE REPORT")
print("============================================")
print(f"Total routes:  {len(real_paths)}")
print(f"Active:        {active}")
print(f"Not found:     {not_found}")
print(f"Skipped:       {skipped}")
print("")

# Save corrected routes
report_file = os.path.join(LOG_DIR, "corrected_routes.json")
with open(report_file, "w") as f:
    json.dump({
        "timestamp": datetime.now().isoformat(),
        "total_routes": len(real_paths),
        "all_routes": real_paths,
        "corrections": wrong_to_correct,
        "test_results": results
    }, f, indent=2)

print(f"Saved: {report_file}")
print("============================================")
