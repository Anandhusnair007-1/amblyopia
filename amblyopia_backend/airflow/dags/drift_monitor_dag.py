"""
Amblyopia Care System — Airflow DAGs
Drift Monitor DAG  +  Model Integrity Audit DAG
"""
from __future__ import annotations

import asyncio
import logging
import os
from datetime import date, datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago

logger = logging.getLogger(__name__)

# ── Shared defaults ────────────────────────────────────────────────────────────
_DEFAULT_ARGS = {
    "owner":            "mlops",
    "depends_on_past":  False,
    "email_on_failure": True,
    "email_on_retry":   False,
    "email":            [os.getenv("ALERT_EMAIL", "admin@amblyopiacare.in")],
    "retries":          1,
    "retry_delay":      timedelta(minutes=10),
}

SLACK_WEBHOOK_URL = os.getenv("SLACK_WEBHOOK_URL")


# ════════════════════════════════════════════════════════════════════════════════
# DAG 1 — Daily Drift Monitor
# ════════════════════════════════════════════════════════════════════════════════

def _run_drift_monitor(**context) -> None:
    """PythonOperator callable — runs the full drift monitoring pipeline."""
    # Use execution_date to get the date being monitored
    execution_date = context["execution_date"].date()
    # We monitor yesterday's completed data
    snapshot_date  = execution_date - timedelta(days=1)

    logger.info("Starting drift monitor for %s", snapshot_date)

    async def _main():
        from app.database import AsyncSessionLocal
        from app.services.drift_monitor import run_drift_monitor

        async with AsyncSessionLocal() as db:
            summary = await run_drift_monitor(
                db=db,
                snapshot_date=snapshot_date,
                slack_webhook_url=SLACK_WEBHOOK_URL,
            )
        logger.info("Drift monitor summary: %s", summary)
        return summary

    summary = asyncio.run(_main())

    # Fail the task if critical drifts were found (triggers retry + email)
    critical_count = summary.get("alerts_by_severity", {}).get("critical", 0)
    if critical_count > 0:
        raise RuntimeError(
            f"Drift monitor detected {critical_count} CRITICAL drift alert(s) "
            f"for {snapshot_date}. Investigate immediately."
        )


def _generate_drift_report(**context) -> None:
    """Generate and upload a text summary report for this cycle."""
    execution_date = context["execution_date"].date()
    snapshot_date  = execution_date - timedelta(days=1)

    async def _main():
        from app.database import AsyncSessionLocal
        from app.services.drift_monitor import detect_drift
        from sqlalchemy.future import select
        from app.services.drift_monitor import DriftSnapshot, DriftAlert

        async with AsyncSessionLocal() as db:
            results = await detect_drift(db, snapshot_date)
            # Fetch alert count
            from sqlalchemy import func
            count_result = await db.execute(
                select(func.count()).select_from(DriftAlert)
                .filter(DriftAlert.alert_date == snapshot_date)
            )
            alert_count = count_result.scalar()

        lines = [
            f"# Drift Monitor Report — {snapshot_date}",
            f"Generated: {datetime.utcnow().isoformat()}Z",
            f"Alerts raised: {alert_count}",
            "",
            "## Metrics",
        ]
        for r in results:
            status = "⚠ DRIFT" if r.is_drift else "✓ OK"
            lines.append(f"- [{status}] {r.message}")

        report = "\n".join(lines)

        # Write to log (in production, upload to S3)
        logger.info("\n%s", report)
        report_path = f"/tmp/drift_report_{snapshot_date}.txt"
        with open(report_path, "w") as f:
            f.write(report)

        # Upload to S3 if configured
        s3_bucket = os.getenv("S3_BUCKET")
        if s3_bucket:
            import subprocess
            subprocess.run(
                ["aws", "s3", "cp", report_path,
                 f"{s3_bucket}/drift-reports/report_{snapshot_date}.txt"],
                check=False,
            )

    asyncio.run(_main())


with DAG(
    dag_id="amblyopia_drift_monitor",
    description="Daily ML output distribution drift detection",
    default_args=_DEFAULT_ARGS,
    schedule_interval="0 6 * * *",     # 06:00 UTC daily (after overnight data is complete)
    start_date=days_ago(1),
    catchup=False,
    max_active_runs=1,
    tags=["mlops", "drift", "monitoring"],
    doc_md="""
## Amblyopia Drift Monitor DAG

Runs every morning to detect statistical drift in model output distributions.

**Metrics monitored:**
- Mean amblyopia risk score
- Strabismus detection rate
- Mean gaze deviation
- Low-brightness image rate
- Mean Snellen test accuracy
- Mean voice screening score

**Alert threshold:** Z-score > 2.0 against 7-day rolling baseline

**On critical drift**: Task fails → triggers Airflow email + Slack notification.
    """,
) as drift_dag:

    t_run_monitor = PythonOperator(
        task_id="run_drift_monitor",
        python_callable=_run_drift_monitor,
        provide_context=True,
        execution_timeout=timedelta(minutes=30),
    )

    t_report = PythonOperator(
        task_id="generate_report",
        python_callable=_generate_drift_report,
        provide_context=True,
        trigger_rule="all_done",   # run even if drift task fails
        execution_timeout=timedelta(minutes=10),
    )

    t_run_monitor >> t_report


# ════════════════════════════════════════════════════════════════════════════════
# DAG 2 — Daily Model Integrity Audit
# ════════════════════════════════════════════════════════════════════════════════

def _run_model_integrity_audit(**context) -> None:
    """Re-verify SHA-256 hashes for all registered model files."""
    logger.info("Starting model integrity audit")

    async def _main():
        from app.database import AsyncSessionLocal
        from app.services.model_integrity import audit_all_models

        async with AsyncSessionLocal() as db:
            results = await audit_all_models(db)

        failed = [k for k, v in results.items() if not v]
        if failed:
            raise RuntimeError(
                f"MODEL INTEGRITY VIOLATIONS ({len(failed)}): {failed}"
            )
        logger.info("Model integrity audit PASSED: %d model(s) verified.", len(results))

    asyncio.run(_main())


def _run_manifest_verification(**context) -> None:
    """Verify local model files against filesystem manifest."""
    from app.services.model_integrity import verify_manifest, _DEFAULT_MODELS_DIR, _MANIFEST_PATH

    if not _MANIFEST_PATH.exists():
        logger.warning("No manifest found at %s — skipping manifest verification", _MANIFEST_PATH)
        return

    passed, failed = verify_manifest(
        model_dir=_DEFAULT_MODELS_DIR,
        manifest_path=_MANIFEST_PATH,
        abort_on_fail=False,
    )
    logger.info("Manifest check: %d PASS / %d FAIL", passed, failed)
    if failed > 0:
        raise RuntimeError(f"Manifest verification: {failed} file(s) failed hash check.")


with DAG(
    dag_id="amblyopia_model_integrity_audit",
    description="Daily SHA-256 verification of all registered ML model files",
    default_args=_DEFAULT_ARGS,
    schedule_interval="0 5 * * *",     # 05:00 UTC daily
    start_date=days_ago(1),
    catchup=False,
    max_active_runs=1,
    tags=["mlsecops", "integrity", "security"],
    doc_md="""
## Model Integrity Audit DAG

Runs every morning to verify that no ML model file has been tampered with,
corrupted, or replaced since registration.

**Method:**
- Re-computes SHA-256 hash of every registered model file
- Compares against the expected hash stored in the database
- Also cross-checks against the local filesystem manifest

**On failure:** Task fails → Airflow email alert sent immediately.
    """,
) as integrity_dag:

    t_db_audit = PythonOperator(
        task_id="db_hash_audit",
        python_callable=_run_model_integrity_audit,
        provide_context=True,
        execution_timeout=timedelta(hours=1),
    )

    t_manifest = PythonOperator(
        task_id="manifest_verification",
        python_callable=_run_manifest_verification,
        provide_context=True,
        execution_timeout=timedelta(minutes=30),
    )

    t_db_audit >> t_manifest
