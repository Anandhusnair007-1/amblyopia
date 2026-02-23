#!/bin/bash
echo "============================================"
echo "AMBLYOPIA CONTROL PANEL — Full Test Suite"
echo "============================================"
echo ""

PROJECT=/home/anandhu/projects/amblyopia_backend
cd $PROJECT
source venv/bin/activate 2>/dev/null || true
mkdir -p logs

# Step 1: Check backend running
echo "Step 1: Checking backend..."
if curl -s http://localhost:8000/health > /dev/null; then
    echo "  Backend: RUNNING ✅"
else
    echo "  Backend: NOT RUNNING"
    echo "  Starting backend..."
    bash run_local.sh &
    sleep 5
    if curl -s http://localhost:8000/health > /dev/null;
    then
        echo "  Backend: STARTED ✅"
    else
        echo "  Backend: FAILED TO START ❌"
        echo "  Run manually: bash run_local.sh"
        exit 1
    fi
fi

# Step 2: Check MLflow
echo ""
echo "Step 2: Checking MLflow..."
if curl -s http://localhost:5050 > /dev/null; then
    echo "  MLflow: RUNNING on 5050 ✅"
elif curl -s http://localhost:5000 > /dev/null; then
    echo "  MLflow: RUNNING on 5000 ✅"
else
    echo "  MLflow: NOT RUNNING"
    echo "  Starting MLflow on port 5050..."
    mlflow server \
        --backend-store-uri ./mlruns \
        --default-artifact-root ./mlruns \
        --host 0.0.0.0 \
        --port 5050 \
        > logs/mlflow.log 2>&1 &
    sleep 3
    echo "  MLflow: STARTED ✅"
fi

# Step 3: Install test dependencies
echo ""
echo "Step 3: Installing test dependencies..."
pip install pytest httpx opencv-python \
    soundfile numpy -q
echo "  Dependencies: READY ✅"

# Step 4: Run backend API tests
echo ""
echo "Step 4: Running backend API tests..."
echo "----------------------------------------"
pytest tests/test_control_panel.py \
    -v \
    --tb=short \
    --no-header \
    -q \
    2>&1 | tee logs/api_test_results.txt
echo "----------------------------------------"

# Step 5: Run new endpoints check
echo ""
echo "Step 5: Checking new control panel endpoints..."
echo "----------------------------------------"
pytest tests/test_control_panel_apis.py \
    -v \
    --tb=short \
    --no-header \
    -q \
    2>&1 | tee logs/endpoint_check_results.txt
echo "----------------------------------------"

# Step 6: Count results
echo ""
PASSED=$(grep -c "PASSED" logs/api_test_results.txt \
    2>/dev/null || echo 0)
FAILED=$(grep -c "FAILED" logs/api_test_results.txt \
    2>/dev/null || echo 0)
SKIPPED=$(grep -c "SKIPPED" logs/api_test_results.txt \
    2>/dev/null || echo 0)

MISSING=$(grep -c "MISSING" \
    logs/endpoint_check_results.txt 2>/dev/null \
    || echo 0)

echo "============================================"
echo "TEST RESULTS SUMMARY"
echo "============================================"
echo "API Tests:"
echo "  PASSED:  $PASSED"
echo "  FAILED:  $FAILED"
echo "  SKIPPED: $SKIPPED"
echo ""
echo "Control Panel Endpoints:"
echo "  MISSING: $MISSING endpoints need creating"
echo ""

if [ "$FAILED" -eq 0 ] && [ "$MISSING" -eq 0 ]; then
    echo "STATUS: ALL TESTS PASSED ✅"
    echo "READY:  Open control_panel.html in browser"
else
    echo "STATUS: ISSUES FOUND"
    if [ "$FAILED" -gt 0 ]; then
        echo "  Fix $FAILED failing API tests"
    fi
    if [ "$MISSING" -gt 0 ]; then
        echo "  Create $MISSING missing endpoints"
        echo "  See: logs/endpoint_check_results.txt"
    fi
fi

# Step 7: Open control panel in browser
echo ""
echo "Step 7: Opening control panel..."
if command -v google-chrome &> /dev/null; then
    google-chrome \
        --new-tab \
        "file://$PROJECT/control_panel.html" \
        &
elif command -v firefox &> /dev/null; then
    firefox "file://$PROJECT/control_panel.html" &
elif command -v xdg-open &> /dev/null; then
    xdg-open "file://$PROJECT/control_panel.html" &
fi

echo ""
echo "============================================"
echo "Control Panel: file://$PROJECT/control_panel.html"
echo "Backend Docs:  http://localhost:8000/docs"
echo "MLflow UI:     http://localhost:5050"
echo "Log files:     $PROJECT/logs/"
echo "============================================"

# Step 8: Generate HTML report
python3 - << 'PYEOF'
import json
import datetime

passed = 0
failed = 0
skipped = 0

try:
    with open("logs/api_test_results.txt") as f:
        content = f.read()
        passed = content.count("PASSED")
        failed = content.count("FAILED")
        skipped = content.count("SKIPPED")
except:
    pass

missing_eps = []
try:
    with open("logs/endpoint_check_results.txt") as f:
        for line in f:
            if "MISSING:" in line:
                missing_eps.append(line.strip())
except:
    pass

total = passed + failed + skipped
score = int((passed / total * 100)) if total > 0 else 0

html = f"""<!DOCTYPE html>
<html>
<head>
<title>Test Report — Amblyopia Care System</title>
<style>
  body {{ 
    font-family: 'Courier New', monospace;
    background: #0A0F1E; color: #00E5FF;
    padding: 20px; margin: 0;
  }}
  h1 {{ color: #00E5FF; border-bottom: 1px solid #1a2744; }}
  .score {{ font-size: 48px; color: #00E676; }}
  .card {{
    background: #0D1B2A; border: 1px solid #1A2744;
    padding: 20px; margin: 10px 0;
    border-radius: 8px;
  }}
  .pass {{ color: #00E676; }}
  .fail {{ color: #FF1744; }}
  .skip {{ color: #FFD740; }}
  table {{ width: 100%; border-collapse: collapse; }}
  td,th {{ padding: 8px; border: 1px solid #1a2744; }}
</style>
</head>
<body>
<h1>🔬 AMBLYOPIA CARE SYSTEM — Test Report</h1>
<p>{datetime.datetime.now().strftime('%Y-%m-%d %H:%M IST')}</p>

<div class="card">
  <div class="score">{score}%</div>
  <p>Test Score — {passed}/{total} tests passing</p>
</div>

<div class="card">
  <h2>Test Results</h2>
  <table>
    <tr><th>Category</th><th>Count</th><th>Status</th></tr>
    <tr>
      <td>PASSED</td>
      <td class="pass">{passed}</td>
      <td class="pass">✅ Working</td>
    </tr>
    <tr>
      <td>FAILED</td>
      <td class="fail">{failed}</td>
      <td class="fail">❌ Need fixing</td>
    </tr>
    <tr>
      <td>SKIPPED</td>
      <td class="skip">{skipped}</td>
      <td class="skip">⚠️ Not implemented yet</td>
    </tr>
  </table>
</div>

<div class="card">
  <h2>Missing Endpoints</h2>
  {'<p class="pass">All endpoints present ✅</p>'
    if not missing_eps else
    '<br>'.join(f'<p class="fail">{{e}}</p>'
    for e in missing_eps)
  }
</div>

<div class="card">
  <h2>Next Steps</h2>
  <p>1. Open control_panel.html and test manually</p>
  <p>2. Upload an eye image → run ESRGAN</p>
  <p>3. Click record → speak a letter</p>
  <p>4. Open camera → verify eye detection</p>
</div>
</body>
</html>"""

with open("logs/test_report.html", "w") as f:
    f.write(html)

print(f"Report saved: logs/test_report.html")
PYEOF

# Open test report
sleep 1
if command -v xdg-open &> /dev/null; then
    xdg-open "logs/test_report.html" &
fi

echo "Test report: file://$PROJECT/logs/test_report.html"
