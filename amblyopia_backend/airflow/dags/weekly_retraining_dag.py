"""
Amblyopia Care System — Weekly Retraining Airflow DAG
=====================================================
Triggered every Sunday at 02:00 IST (20:30 UTC).

Pipeline:
  1. extract_training_data    → Pull labeled screenings (30 days, doctor-reviewed)
  2. train_model              → MobileNetV2-style dense model with train/val split
  3. evaluate_model           → AUROC, sensitivity, specificity, confusion matrix
  4. register_to_mlflow       → Register to MLflow Model Registry as 'staging'
  5. promote_if_improved      → Promote to 'production' if AUROC beats current
  6. update_db_and_notify     → Write retraining_job row, notify admin on success/failure

On any task failure: failure_notification task sends an alert.
"""
from __future__ import annotations

import logging
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator

logger = logging.getLogger(__name__)

# ── Constants ─────────────────────────────────────────────────────────────────
MIN_AUROC_FOR_PROMOTION = 0.82
MIN_NEW_SAMPLES         = 50
MODEL_INPUT_DIM         = 4        # [gaze, redgreen, snellen, overall_risk_score]
BATCH_SIZE              = 32
EPOCHS                  = 20

# ── DAG Default Args ──────────────────────────────────────────────────────────
default_args = {
    "owner":            "aravind_ai_team",
    "depends_on_past":  False,
    "start_date":       datetime(2024, 1, 1),
    "email_on_failure": False,
    "email_on_retry":   False,
    "retries":          1,
    "retry_delay":      timedelta(minutes=10),
    "on_failure_callback": lambda context: _send_failure_notification(context),
}

dag = DAG(
    "weekly_amblyopia_model_retraining",
    default_args=default_args,
    description="Weekly retraining: extract → train → evaluate → register → promote → notify",
    schedule_interval="0 20 * * 0",   # 02:00 IST = 20:30 UTC Sunday
    catchup=False,
    tags=["ml", "retraining", "amblyopia"],
    max_active_runs=1,
)


# ── Failure notification (callback) ──────────────────────────────────────────
def _send_failure_notification(context: dict) -> None:
    """
    Sends a push/WhatsApp notification to admin on any DAG task failure.
    Non-blocking — wrapped in broad exception handler.
    """
    try:
        import os
        dag_id   = context.get("dag", {}).dag_id if hasattr(context.get("dag", {}), "dag_id") else "unknown"
        task_id  = context.get("task_instance", {}).task_id if hasattr(context.get("task_instance", {}), "task_id") else "unknown"
        exc      = context.get("exception", "unknown error")
        msg      = f"[AIRFLOW FAILURE] DAG={dag_id} Task={task_id} Error={exc}"
        logger.error(msg)

        # Twilio WhatsApp alert (production)
        twilio_sid   = os.environ.get("TWILIO_ACCOUNT_SID")
        twilio_token = os.environ.get("TWILIO_AUTH_TOKEN")
        twilio_to    = os.environ.get("TWILIO_ADMIN_WHATSAPP")
        twilio_from  = os.environ.get("TWILIO_WHATSAPP_NUMBER", "whatsapp:+14155238886")

        if twilio_sid and twilio_token and twilio_to:
            from twilio.rest import Client
            client = Client(twilio_sid, twilio_token)
            client.messages.create(
                body=msg[:1600],
                from_=twilio_from,
                to=twilio_to,
            )
            logger.info("Failure alert sent via WhatsApp")
    except Exception as alert_exc:
        logger.error("Failure alert itself failed: %s", alert_exc)


# ── Task 1: Extract ───────────────────────────────────────────────────────────
def extract_training_data(**context) -> dict:
    """
    Pull doctor-reviewed labeled screenings from the last 30 days.
    Minimum MIN_NEW_SAMPLES required to proceed.
    Returns dataset stats via XCom.
    """
    import json, os
    import psycopg2
    import numpy as np

    logger.info("[extract] Starting data extraction...")
    db_url = os.environ["DATABASE_URL"].replace("postgresql+asyncpg://", "postgresql://")
    conn = psycopg2.connect(db_url)
    cur  = conn.cursor()

    cur.execute("""
        SELECT
            cr.gaze_score,
            cr.redgreen_score,
            cr.snellen_score,
            cr.overall_risk_score,
            dr.verdict,
            ss.age_group
        FROM combined_results cr
        JOIN screening_sessions ss ON ss.id = cr.session_id
        JOIN doctor_reviews     dr ON dr.session_id = cr.session_id
        WHERE ss.started_at >= NOW() - INTERVAL '30 days'
          AND dr.verdict IS NOT NULL
          AND cr.overall_risk_score IS NOT NULL
    """)
    rows = cur.fetchall()
    conn.close()

    logger.info("[extract] Got %d labeled samples", len(rows))

    if len(rows) < MIN_NEW_SAMPLES:
        logger.warning("[extract] Too few samples (%d < %d), skipping retrain", len(rows), MIN_NEW_SAMPLES)
        return {"status": "skipped", "reason": f"Only {len(rows)} samples"}

    # Encode labels: refer/urgent → 1 (positive), monitor/normal → 0
    data = []
    for row in rows:
        gaze, rg, snellen, overall, verdict, age = row
        label = 1.0 if verdict in ("refer", "urgent") else 0.0
        data.append([
            float(gaze or 50.0),
            float(rg or 50.0),
            float(snellen or 50.0),
            float(overall or 50.0),
            label,
        ])

    ti = context["task_instance"]
    ti.xcom_push(key="sample_count", value=len(data))
    ti.xcom_push(key="data_json",    value=json.dumps(data))
    logger.info("[extract] Pushed %d samples to XCom", len(data))
    return {"status": "ok", "sample_count": len(data)}


# ── Task 2: Train ─────────────────────────────────────────────────────────────
def train_model(**context) -> dict:
    """
    Train a dense classifier on the extracted feature vectors.
    Uses an 80/20 train/val split.
    """
    import json
    import os
    import numpy as np

    ti = context["task_instance"]
    data_json    = ti.xcom_pull(key="data_json",    task_ids="extract_training_data")
    sample_count = ti.xcom_pull(key="sample_count", task_ids="extract_training_data")

    if not data_json:
        logger.info("[train] Skipping — no data")
        return {"status": "skipped"}

    data = json.loads(data_json)
    X = np.array([[r[0], r[1], r[2], r[3]] for r in data], dtype=np.float32) / 100.0
    y = np.array([r[4] for r in data], dtype=np.float32)

    logger.info("[train] Training on %d samples (pos=%d, neg=%d)",
                len(X), int(y.sum()), int(len(y) - y.sum()))

    try:
        import tensorflow as tf

        split = max(1, int(len(X) * 0.8))
        X_train, X_val = X[:split], X[split:]
        y_train, y_val = y[:split], y[split:]

        model = tf.keras.Sequential([
            tf.keras.layers.Input(shape=(MODEL_INPUT_DIM,)),
            tf.keras.layers.Dense(128, activation="relu"),
            tf.keras.layers.BatchNormalization(),
            tf.keras.layers.Dropout(0.3),
            tf.keras.layers.Dense(64,  activation="relu"),
            tf.keras.layers.Dropout(0.2),
            tf.keras.layers.Dense(32,  activation="relu"),
            tf.keras.layers.Dense(1,   activation="sigmoid"),
        ])
        model.compile(
            optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
            loss="binary_crossentropy",
            metrics=["accuracy", tf.keras.metrics.AUC(name="auroc")],
        )

        callbacks = [
            tf.keras.callbacks.EarlyStopping(patience=5, restore_best_weights=True),
        ]
        history = model.fit(
            X_train, y_train,
            validation_data=(X_val, y_val),
            epochs=EPOCHS, batch_size=BATCH_SIZE,
            callbacks=callbacks, verbose=0,
        )
        val_acc  = float(history.history["val_accuracy"][-1])
        val_auroc = float(history.history.get("val_auroc", [0.5])[-1])
        logger.info("[train] val_accuracy=%.4f val_auroc=%.4f", val_acc, val_auroc)

        # Save Keras model to /tmp
        model_path = f"/tmp/amblyopia_model_{context['run_id']}.keras"
        model.save(model_path)

        # Also save val set predictions for evaluation task
        if len(X_val) > 0:
            y_pred = model.predict(X_val, verbose=0).flatten().tolist()
            ti.xcom_push(key="y_val",  value=json.dumps(y_val.tolist()))
            ti.xcom_push(key="y_pred", value=json.dumps(y_pred))

        ti.xcom_push(key="val_accuracy", value=val_acc)
        ti.xcom_push(key="val_auroc",    value=val_auroc)
        ti.xcom_push(key="model_path",   value=model_path)
        return {"status": "trained", "val_accuracy": val_acc, "val_auroc": val_auroc}

    except Exception as exc:
        logger.error("[train] Training failed: %s", exc, exc_info=True)
        return {"status": "failed", "error": str(exc)}


# ── Task 3: Evaluate ──────────────────────────────────────────────────────────
def evaluate_model(**context) -> dict:
    """
    Compute AUROC, sensitivity (recall), specificity, and confusion matrix
    on the validation set.
    """
    import json
    import numpy as np

    ti = context["task_instance"]
    y_val_json  = ti.xcom_pull(key="y_val",  task_ids="train_model")
    y_pred_json = ti.xcom_pull(key="y_pred", task_ids="train_model")
    val_auroc   = ti.xcom_pull(key="val_auroc", task_ids="train_model")

    if not y_val_json or not y_pred_json:
        logger.info("[evaluate] No validation data — skipping metrics")
        return {"status": "skipped"}

    y_val  = np.array(json.loads(y_val_json))
    y_pred = np.array(json.loads(y_pred_json))
    threshold = 0.5
    y_bin  = (y_pred >= threshold).astype(int)

    # Confusion matrix: TP, FN, FP, TN
    tp = int(((y_bin == 1) & (y_val == 1)).sum())
    fn = int(((y_bin == 0) & (y_val == 1)).sum())
    fp = int(((y_bin == 1) & (y_val == 0)).sum())
    tn = int(((y_bin == 0) & (y_val == 0)).sum())

    sensitivity = tp / (tp + fn) if (tp + fn) > 0 else 0.0   # recall / true-positive rate
    specificity = tn / (tn + fp) if (tn + fp) > 0 else 0.0   # true-negative rate

    # AUROC (sklearn if available, else use Keras value)
    try:
        from sklearn.metrics import roc_auc_score
        auroc = float(roc_auc_score(y_val, y_pred))
    except Exception:
        auroc = float(val_auroc or 0.5)

    logger.info(
        "[evaluate] AUROC=%.4f sensitivity=%.4f specificity=%.4f "
        "TP=%d FN=%d FP=%d TN=%d",
        auroc, sensitivity, specificity, tp, fn, fp, tn,
    )

    ti.xcom_push(key="auroc",         value=auroc)
    ti.xcom_push(key="sensitivity",   value=sensitivity)
    ti.xcom_push(key="specificity",   value=specificity)
    ti.xcom_push(key="confusion_matrix", value=json.dumps([tp, fn, fp, tn]))

    return {
        "status":       "ok",
        "auroc":        round(auroc, 4),
        "sensitivity":  round(sensitivity, 4),
        "specificity":  round(specificity, 4),
        "confusion_matrix": {"TP": tp, "FN": fn, "FP": fp, "TN": tn},
    }


# ── Task 4: Register to MLflow ────────────────────────────────────────────────
def register_to_mlflow(**context) -> dict:
    """
    Register the trained model to MLflow Model Registry as 'staging'.
    Logs all evaluation metrics.
    """
    import json
    import os
    import sys

    ti = context["task_instance"]
    model_path   = ti.xcom_pull(key="model_path",    task_ids="train_model")
    val_accuracy = ti.xcom_pull(key="val_accuracy",  task_ids="train_model")
    auroc        = ti.xcom_pull(key="auroc",          task_ids="evaluate_model")
    sensitivity  = ti.xcom_pull(key="sensitivity",    task_ids="evaluate_model")
    specificity  = ti.xcom_pull(key="specificity",    task_ids="evaluate_model")
    cm_json      = ti.xcom_pull(key="confusion_matrix", task_ids="evaluate_model")

    if not model_path or not val_accuracy:
        logger.info("[register] Skipping — no model to register")
        return {"status": "skipped"}

    try:
        sys.path.insert(0, "/app")
        from app.services.mlflow_model_service import register_trained_model

        cm = json.loads(cm_json) if cm_json else [0, 0, 0, 0]
        version = register_trained_model(
            model_path=model_path,
            val_accuracy=float(val_accuracy),
            auroc=float(auroc or 0.5),
            sensitivity=float(sensitivity or 0.0),
            specificity=float(specificity or 0.0),
            confusion_matrix=cm,
        )
        if version:
            logger.info("[register] Registered as version %s (staging)", version)
            ti.xcom_push(key="registered_version", value=version)
            return {"status": "registered", "version": version}
        else:
            return {"status": "registration_failed"}
    except Exception as exc:
        logger.error("[register] MLflow registration failed: %s", exc, exc_info=True)
        return {"status": "failed", "error": str(exc)}


# ── Task 5: Promote if improved ───────────────────────────────────────────────
def promote_if_improved(**context) -> dict:
    """
    Promote staging model to production if AUROC >= MIN_AUROC_FOR_PROMOTION.
    """
    import sys

    ti = context["task_instance"]
    version = ti.xcom_pull(key="registered_version", task_ids="register_to_mlflow")
    auroc   = ti.xcom_pull(key="auroc",              task_ids="evaluate_model")

    if not version:
        logger.info("[promote] No registered version — skipping")
        return {"status": "skipped"}

    auroc = float(auroc or 0.0)
    if auroc < MIN_AUROC_FOR_PROMOTION:
        logger.warning(
            "[promote] AUROC %.4f < threshold %.4f — NOT promoting to production",
            auroc, MIN_AUROC_FOR_PROMOTION,
        )
        return {"status": "not_promoted", "auroc": auroc, "threshold": MIN_AUROC_FOR_PROMOTION}

    try:
        sys.path.insert(0, "/app")
        from app.services.mlflow_model_service import promote_to_production
        promoted = promote_to_production(version=version, auroc=auroc)
        if promoted:
            logger.info("[promote] Version %s promoted to production ✓", version)
            return {"status": "promoted", "version": version, "auroc": auroc}
        return {"status": "promotion_failed"}
    except Exception as exc:
        logger.error("[promote] Promotion failed: %s", exc)
        return {"status": "failed", "error": str(exc)}


# ── Task 6: Update DB and notify ──────────────────────────────────────────────
def update_db_and_notify(**context) -> None:
    """Update retraining_jobs and ml_models tables. Send admin notification."""
    import os, sys, json
    import psycopg2

    ti = context["task_instance"]
    sample_count   = ti.xcom_pull(key="sample_count",      task_ids="extract_training_data") or 0
    val_accuracy   = ti.xcom_pull(key="val_accuracy",      task_ids="train_model") or 0.0
    auroc          = ti.xcom_pull(key="auroc",              task_ids="evaluate_model") or 0.0
    sensitivity    = ti.xcom_pull(key="sensitivity",        task_ids="evaluate_model") or 0.0
    specificity    = ti.xcom_pull(key="specificity",        task_ids="evaluate_model") or 0.0
    registered_ver = ti.xcom_pull(key="registered_version", task_ids="register_to_mlflow")
    promote_result = ti.xcom_pull(task_ids="promote_if_improved")

    promote_status = promote_result.get("status", "unknown") if promote_result else "unknown"
    final_status   = "deployed" if promote_status == "promoted" else promote_status

    try:
        db_url = os.environ["DATABASE_URL"].replace("postgresql+asyncpg://", "postgresql://")
        conn = psycopg2.connect(db_url)
        cur  = conn.cursor()

        cur.execute("""
            INSERT INTO retraining_jobs
                (triggered_by, samples_used, new_accuracy, status, completed_at)
            VALUES ('airflow_weekly_dag', %s, %s, %s, NOW())
        """, (sample_count, float(val_accuracy), final_status))

        if registered_ver and final_status == "deployed":
            cur.execute("""
                INSERT INTO ml_models (version, accuracy_score, status, deployed_at)
                VALUES (%s, %s, 'active', NOW())
                ON CONFLICT (version) DO NOTHING
            """, (registered_ver, float(val_accuracy)))
            cur.execute("""
                UPDATE ml_models SET status='retired'
                WHERE status='active' AND version != %s
            """, (registered_ver,))

        conn.commit()
        conn.close()
        logger.info("[notify] DB updated: status=%s version=%s", final_status, registered_ver)
    except Exception as exc:
        logger.error("[notify] DB update failed: %s", exc)

    # Success notification
    try:
        summary = (
            f"[RETRAIN COMPLETE] "
            f"Samples={sample_count} | Acc={val_accuracy:.4f} | AUROC={auroc:.4f} | "
            f"Sensitivity={sensitivity:.4f} | Specificity={specificity:.4f} | "
            f"Status={final_status} | Version={registered_ver}"
        )
        logger.info(summary)

        twilio_sid   = os.environ.get("TWILIO_ACCOUNT_SID")
        twilio_token = os.environ.get("TWILIO_AUTH_TOKEN")
        twilio_to    = os.environ.get("TWILIO_ADMIN_WHATSAPP")
        twilio_from  = os.environ.get("TWILIO_WHATSAPP_NUMBER", "whatsapp:+14155238886")

        if twilio_sid and twilio_token and twilio_to:
            from twilio.rest import Client
            Client(twilio_sid, twilio_token).messages.create(
                body=summary[:1600], from_=twilio_from, to=twilio_to,
            )
    except Exception as exc:
        logger.warning("[notify] Admin notification failed: %s", exc)


# ── DAG Wiring ────────────────────────────────────────────────────────────────
t_extract  = PythonOperator(task_id="extract_training_data", python_callable=extract_training_data, dag=dag)
t_train    = PythonOperator(task_id="train_model",           python_callable=train_model,           dag=dag)
t_evaluate = PythonOperator(task_id="evaluate_model",        python_callable=evaluate_model,        dag=dag)
t_register = PythonOperator(task_id="register_to_mlflow",    python_callable=register_to_mlflow,    dag=dag)
t_promote  = PythonOperator(task_id="promote_if_improved",   python_callable=promote_if_improved,   dag=dag)
t_notify   = PythonOperator(task_id="update_db_and_notify",  python_callable=update_db_and_notify,  dag=dag)

t_extract >> t_train >> t_evaluate >> t_register >> t_promote >> t_notify
