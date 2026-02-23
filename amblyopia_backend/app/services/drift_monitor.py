"""
Amblyopia Care System — ML Drift Monitor
=========================================
Detects statistical drift in model outputs to surface data distribution
shifts, model degradation, or population changes.

Monitored signals (daily aggregation):
  - mean_risk_score           : float [0–1] — average amblyopia risk
  - strabismus_rate           : float [0–1] — fraction of positive strabismus detections
  - gaze_deviation_mean       : float (°)   — mean gaze deviation from tests
  - low_brightness_rate       : float [0–1] — fraction of images below brightness threshold
  - snellen_accuracy_mean     : float [0–1] — mean Snellen test accuracy
  - voice_score_mean          : float [0–1] — mean voice screening score

Detection method:
  Computes a 7-day rolling baseline (mean ± std). Raises an alert when the
  current day's value deviates by more than 2 standard deviations from the
  baseline mean (z-score threshold = 2.0).

Outputs:
  - DB records in ``drift_snapshots`` table
  - Prometheus gauge: ``amblyopia_drift_zscore{metric="..."}``
  - Slack / email alert when threshold exceeded
"""
from __future__ import annotations

import logging
import statistics
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import Column, Date, DateTime, Float, Integer, String, Text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.database import Base

logger = logging.getLogger(__name__)

# ── Configuration ─────────────────────────────────────────────────────────────
DRIFT_ZSCORE_THRESHOLD = 2.0     # standard deviations before alert
ROLLING_WINDOW_DAYS   = 7        # baseline window length
MIN_SAMPLE_DAYS       = 3        # minimum days of history needed before alerting

# Metric definitions: (column_name, human_label, alert_severity)
MONITORED_METRICS: list[tuple[str, str, str]] = [
    ("mean_risk_score",      "Mean Amblyopia Risk Score",          "critical"),
    ("strabismus_rate",      "Strabismus Detection Rate",          "warning"),
    ("gaze_deviation_mean",  "Mean Gaze Deviation (°)",            "warning"),
    ("low_brightness_rate",  "Low-Brightness Image Rate",          "info"),
    ("snellen_accuracy_mean","Mean Snellen Test Accuracy",         "warning"),
    ("voice_score_mean",     "Mean Voice Screening Score",         "warning"),
]


# ── ORM Models ────────────────────────────────────────────────────────────────

class DriftSnapshot(Base):
    """Daily aggregated metric snapshot for drift detection."""
    __tablename__ = "drift_snapshots"

    id                   = Column(Integer, primary_key=True, index=True)
    snapshot_date        = Column(Date, nullable=False, index=True, unique=True)
    sample_count         = Column(Integer, nullable=False, default=0)

    # Monitored metric columns (daily aggregate)
    mean_risk_score      = Column(Float, nullable=True)
    strabismus_rate      = Column(Float, nullable=True)
    gaze_deviation_mean  = Column(Float, nullable=True)
    low_brightness_rate  = Column(Float, nullable=True)
    snellen_accuracy_mean = Column(Float, nullable=True)
    voice_score_mean     = Column(Float, nullable=True)

    computed_at          = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


class DriftAlert(Base):
    """Record of each drift alert raised."""
    __tablename__ = "drift_alerts"

    id             = Column(Integer, primary_key=True, index=True)
    alert_date     = Column(Date, nullable=False, index=True)
    metric_name    = Column(String(128), nullable=False)
    current_value  = Column(Float, nullable=False)
    baseline_mean  = Column(Float, nullable=True)
    baseline_std   = Column(Float, nullable=True)
    z_score        = Column(Float, nullable=True)
    severity       = Column(String(32), nullable=False, default="warning")
    message        = Column(Text, nullable=False)
    notified_at    = Column(DateTime(timezone=True), nullable=True)


# ── Data classes ──────────────────────────────────────────────────────────────

@dataclass
class DriftResult:
    metric_name:   str
    current_value: float
    baseline_mean: Optional[float]
    baseline_std:  Optional[float]
    z_score:       Optional[float]
    is_drift:      bool
    severity:      str
    message:       str


# ── Core aggregation ──────────────────────────────────────────────────────────

async def compute_daily_snapshot(
    db:            AsyncSession,
    snapshot_date: date | None = None,
) -> DriftSnapshot:
    """Aggregate today's (or *snapshot_date*'s) screening metrics.

    Queries the ``screenings`` and related tables, computes the metrics,
    and upserts a :class:`DriftSnapshot` row.

    Args:
        db:            Active async DB session.
        snapshot_date: The date to aggregate (default: today).

    Returns:
        The persisted :class:`DriftSnapshot`.
    """
    from sqlalchemy import func, text

    if snapshot_date is None:
        snapshot_date = date.today()

    day_start = datetime.combine(snapshot_date, datetime.min.time()).replace(tzinfo=timezone.utc)
    day_end   = day_start + timedelta(days=1)

    # ── Raw aggregation query (adjust table/column names to match your schema)
    # Wrapped in raw SQL for performance on large tables
    sql = text("""
        SELECT
            COUNT(*)                                        AS sample_count,
            AVG(s.risk_score)                               AS mean_risk_score,
            AVG(CASE WHEN s.strabismus_detected THEN 1.0 ELSE 0.0 END)
                                                            AS strabismus_rate,
            AVG(g.deviation_angle)                          AS gaze_deviation_mean,
            AVG(CASE WHEN i.mean_brightness < 0.3 THEN 1.0 ELSE 0.0 END)
                                                            AS low_brightness_rate,
            AVG(sn.accuracy_score)                          AS snellen_accuracy_mean,
            AVG(v.voice_score)                              AS voice_score_mean
        FROM screenings s
        LEFT JOIN gaze_tests     g  ON g.screening_id = s.id
        LEFT JOIN image_metadata i  ON i.screening_id = s.id
        LEFT JOIN snellen_tests  sn ON sn.screening_id = s.id
        LEFT JOIN voice_tests    v  ON v.screening_id  = s.id
        WHERE s.created_at >= :day_start
          AND s.created_at <  :day_end
    """)

    result = await db.execute(sql, {"day_start": day_start, "day_end": day_end})
    row = result.mappings().first()

    # Upsert snapshot
    existing = await db.execute(
        select(DriftSnapshot).filter_by(snapshot_date=snapshot_date)
    )
    snapshot = existing.scalar_one_or_none()

    if snapshot is None:
        snapshot = DriftSnapshot(snapshot_date=snapshot_date)
        db.add(snapshot)

    snapshot.sample_count         = int(row["sample_count"] or 0)
    snapshot.mean_risk_score      = row["mean_risk_score"]
    snapshot.strabismus_rate      = row["strabismus_rate"]
    snapshot.gaze_deviation_mean  = row["gaze_deviation_mean"]
    snapshot.low_brightness_rate  = row["low_brightness_rate"]
    snapshot.snellen_accuracy_mean = row["snellen_accuracy_mean"]
    snapshot.voice_score_mean     = row["voice_score_mean"]
    snapshot.computed_at          = datetime.now(timezone.utc)

    await db.commit()
    await db.refresh(snapshot)
    logger.info(
        "Drift snapshot: date=%s, n=%d, risk_mean=%.3f",
        snapshot_date, snapshot.sample_count,
        snapshot.mean_risk_score or 0.0,
    )
    return snapshot


# ── Drift detection ────────────────────────────────────────────────────────────

async def detect_drift(
    db:            AsyncSession,
    snapshot_date: date | None = None,
    window_days:   int = ROLLING_WINDOW_DAYS,
    threshold:     float = DRIFT_ZSCORE_THRESHOLD,
) -> list[DriftResult]:
    """Run drift detection for *snapshot_date* against a rolling baseline.

    Args:
        db:            Active async DB session.
        snapshot_date: Target date to evaluate (default: today).
        window_days:   Number of historical days for baseline (default: 7).
        threshold:     Z-score threshold above which drift is flagged (default: 2.0).

    Returns:
        List of :class:`DriftResult` — one per monitored metric.
    """
    if snapshot_date is None:
        snapshot_date = date.today()

    # Load current snapshot
    cur_result = await db.execute(
        select(DriftSnapshot).filter_by(snapshot_date=snapshot_date)
    )
    current = cur_result.scalar_one_or_none()

    if current is None:
        logger.warning("No snapshot for %s — run compute_daily_snapshot first", snapshot_date)
        return []

    # Load baseline window (preceding *window_days* days, excluding today)
    window_start = snapshot_date - timedelta(days=window_days)
    hist_result  = await db.execute(
        select(DriftSnapshot)
        .filter(
            DriftSnapshot.snapshot_date >= window_start,
            DriftSnapshot.snapshot_date <  snapshot_date,
        )
        .order_by(DriftSnapshot.snapshot_date)
    )
    history = hist_result.scalars().all()

    drift_results: list[DriftResult] = []

    for col_name, label, severity in MONITORED_METRICS:
        current_val = getattr(current, col_name)
        if current_val is None:
            continue

        historical_vals = [
            v for snap in history
            if (v := getattr(snap, col_name)) is not None
        ]

        if len(historical_vals) < MIN_SAMPLE_DAYS:
            # Not enough history — report but don't flag
            drift_results.append(DriftResult(
                metric_name=col_name,
                current_value=current_val,
                baseline_mean=None,
                baseline_std=None,
                z_score=None,
                is_drift=False,
                severity="info",
                message=f"{label}: insufficient history ({len(historical_vals)} < {MIN_SAMPLE_DAYS} days)",
            ))
            continue

        baseline_mean = statistics.mean(historical_vals)
        baseline_std  = statistics.pstdev(historical_vals)

        if baseline_std == 0:
            # All historical values identical — any change is notable
            z_score  = 0.0 if current_val == baseline_mean else float("inf")
            is_drift = (current_val != baseline_mean)
        else:
            z_score  = abs(current_val - baseline_mean) / baseline_std
            is_drift = z_score > threshold

        direction = "↑" if current_val > baseline_mean else "↓"
        message = (
            f"{label}: {current_val:.4f} {direction} "
            f"(baseline {baseline_mean:.4f} ± {baseline_std:.4f}, "
            f"z={z_score:.2f})"
        )

        if is_drift:
            logger.warning("DRIFT DETECTED: %s", message)
        else:
            logger.debug("No drift: %s", message)

        drift_results.append(DriftResult(
            metric_name=col_name,
            current_value=current_val,
            baseline_mean=baseline_mean,
            baseline_std=baseline_std,
            z_score=z_score,
            is_drift=is_drift,
            severity=severity if is_drift else "ok",
            message=message,
        ))

    return drift_results


# ── Alert persistence & dispatch ──────────────────────────────────────────────

async def persist_and_dispatch_alerts(
    db:      AsyncSession,
    results: list[DriftResult],
    target_date: date | None = None,
    slack_webhook_url: str | None = None,
) -> list[DriftAlert]:
    """Save drift alerts to the DB and optionally post to Slack.

    Only persists :class:`DriftResult` entries where ``is_drift=True``.

    Args:
        db:                 Active async DB session.
        results:            Output from :func:`detect_drift`.
        target_date:        Date being reported (default: today).
        slack_webhook_url:  If provided, post a Slack message summary.

    Returns:
        List of persisted :class:`DriftAlert` records.
    """
    import json
    try:
        import httpx
        _httpx_available = True
    except ImportError:
        _httpx_available = False

    if target_date is None:
        target_date = date.today()

    alerts: list[DriftAlert] = []

    for dr in results:
        if not dr.is_drift:
            continue

        alert = DriftAlert(
            alert_date=target_date,
            metric_name=dr.metric_name,
            current_value=dr.current_value,
            baseline_mean=dr.baseline_mean,
            baseline_std=dr.baseline_std,
            z_score=dr.z_score,
            severity=dr.severity,
            message=dr.message,
        )
        db.add(alert)
        alerts.append(alert)

    if alerts:
        await db.commit()
        for a in alerts:
            await db.refresh(a)
        logger.info("Persisted %d drift alert(s) for %s", len(alerts), target_date)

        # Slack notification
        if slack_webhook_url and _httpx_available:
            lines = [f"*Amblyopia Drift Alerts — {target_date}*"]
            for a in alerts:
                lines.append(f"• [{a.severity.upper()}] {a.message}")
            payload = {"text": "\n".join(lines)}
            try:
                async with httpx.AsyncClient(timeout=5.0) as client:
                    await client.post(
                        slack_webhook_url,
                        content=json.dumps(payload),
                        headers={"Content-Type": "application/json"},
                    )
                for a in alerts:
                    a.notified_at = datetime.now(timezone.utc)
                await db.commit()
                logger.info("Slack notification sent for %d alert(s).", len(alerts))
            except Exception as exc:
                logger.error("Failed to send Slack notification: %s", exc)

    return alerts


# ── Prometheus integration ─────────────────────────────────────────────────────

def publish_drift_metrics(results: list[DriftResult]) -> None:
    """Update Prometheus gauges with the latest drift z-scores.

    Silently does nothing if ``prometheus_client`` is not installed.

    Args:
        results: Output from :func:`detect_drift`.
    """
    try:
        from prometheus_client import Gauge
    except ImportError:
        return

    _DRIFT_GAUGE: dict[str, Gauge] = {}

    for dr in results:
        if dr.z_score is None:
            continue
        gauge_name = "amblyopia_drift_zscore"
        if gauge_name not in _DRIFT_GAUGE:
            _DRIFT_GAUGE[gauge_name] = Gauge(
                gauge_name,
                "Drift z-score for monitored model output metrics",
                ["metric"],
            )
        _DRIFT_GAUGE[gauge_name].labels(metric=dr.metric_name).set(dr.z_score)


# ── High-level runner (called by Airflow DAG) ─────────────────────────────────

async def run_drift_monitor(
    db:                 AsyncSession,
    snapshot_date:      date | None = None,
    slack_webhook_url:  str | None  = None,
) -> dict:
    """Full drift monitoring pipeline: aggregate → detect → alert → publish.

    Orchestrates :func:`compute_daily_snapshot`, :func:`detect_drift`,
    :func:`persist_and_dispatch_alerts`, and :func:`publish_drift_metrics`.

    Args:
        db:                Active async DB session.
        snapshot_date:     Target date (default: yesterday, for completed data).
        slack_webhook_url: Optional Slack webhook for alert dispatch.

    Returns:
        Summary dict with counts of alerts by severity.
    """
    if snapshot_date is None:
        snapshot_date = date.today() - timedelta(days=1)   # yesterday's data

    logger.info("=== Drift monitor START: %s ===", snapshot_date)

    await compute_daily_snapshot(db, snapshot_date)
    results = await detect_drift(db, snapshot_date)
    alerts  = await persist_and_dispatch_alerts(db, results, snapshot_date, slack_webhook_url)
    publish_drift_metrics(results)

    summary = {
        "date":          str(snapshot_date),
        "metrics_checked": len(results),
        "drift_detected":  len(alerts),
        "alerts_by_severity": {
            "critical": sum(1 for a in alerts if a.severity == "critical"),
            "warning":  sum(1 for a in alerts if a.severity == "warning"),
            "info":     sum(1 for a in alerts if a.severity == "info"),
        },
    }
    logger.info("=== Drift monitor END: %s ===", summary)
    return summary
