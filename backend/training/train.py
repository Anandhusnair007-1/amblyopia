import hashlib
import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

import numpy as np
import tensorflow as tf
from sklearn.metrics import roc_auc_score, recall_score
from sklearn.model_selection import train_test_split
from tensorflow.keras import Input, Model
from tensorflow.keras.layers import Dense
from tensorflow.keras.optimizers import AdamW

from database import get_session
from models import ModelRegistry, SyncedSession, TrainingRun

MODEL_ROOT = Path(os.getenv("MODEL_ROOT", "/tmp/ambyoai_models"))
MODEL_ROOT.mkdir(parents=True, exist_ok=True)

TRAINING_LOCK = False
MIN_NEW_LABELS = 50
MIN_HOURS_BETWEEN_RUNS = 24


def run_training_pipeline():
    global TRAINING_LOCK
    if TRAINING_LOCK:
        return {"status": "skipped", "reason": "training already in progress"}

    TRAINING_LOCK = True
    run = None
    try:
        with get_session() as session:
            last_run = session.query(TrainingRun).order_by(TrainingRun.started_at.desc()).first()
            if last_run and datetime.now(timezone.utc) - last_run.started_at < timedelta(hours=MIN_HOURS_BETWEEN_RUNS):
                return {"status": "skipped", "reason": "minimum interval not reached"}

            labeled_rows = (
                session.query(SyncedSession)
                .filter(SyncedSession.label.is_not(None))
                .order_by(SyncedSession.updated_at.desc())
                .all()
            )
            if len(labeled_rows) < MIN_NEW_LABELS:
                return {"status": "skipped", "reason": "not enough new labeled samples"}

            run = TrainingRun(status="running", triggered=True, samples_used=len(labeled_rows))
            session.add(run)
            session.flush()

            features, labels = _prepare_dataset(labeled_rows)
            x_train, x_val, y_train, y_val = train_test_split(
                features,
                labels,
                test_size=0.15,
                stratify=labels,
                random_state=42,
            )

            model = _build_model()
            model.fit(x_train, tf.keras.utils.to_categorical(y_train, 4), epochs=20, batch_size=32, verbose=0)

            probabilities = model.predict(x_val, verbose=0)
            predicted = np.argmax(probabilities, axis=1)
            auroc = _safe_multiclass_auroc(y_val, probabilities)
            sensitivity = recall_score(y_val, predicted, average="macro", zero_division=0)

            run.auroc = float(auroc)
            run.sensitivity = float(sensitivity)
            if auroc <= 0.85 or sensitivity <= 0.90:
                run.status = "rejected"
                run.completed_at = datetime.now(timezone.utc)
                return {"status": "rejected", "auroc": auroc, "sensitivity": sensitivity}

            version = _next_version(session)
            model_path = MODEL_ROOT / f"ambyo_model_v{version}.tflite"
            _export_tflite(model, model_path)
            checksum = hashlib.sha256(model_path.read_bytes()).hexdigest()

            session.add(
                ModelRegistry(
                    version=version,
                    storage_path=model_path.name,
                    checksum=checksum,
                    auroc=float(auroc),
                    sensitivity=float(sensitivity),
                    is_active=True,
                )
            )

            run.status = "completed"
            run.completed_at = datetime.now(timezone.utc)
            return {
                "status": "completed",
                "version": version,
                "auroc": auroc,
                "sensitivity": sensitivity,
                "checksum": checksum,
            }
    finally:
        TRAINING_LOCK = False


def _prepare_dataset(rows):
    features = []
    labels = []
    for row in rows:
        payload = json.loads(row.payload_json)
        features.append(
            [
                float(payload.get("visual_acuity", 0.0)),
                float(payload.get("gaze_deviation", 0.0)),
                float(payload.get("prism_diopter", 0.0)),
                float(payload.get("suppression_level", 0.0)),
                float(payload.get("depth_score", 0.0)),
                float(payload.get("stereo_score", 0.0)),
                float(payload.get("color_score", 0.0)),
                float(payload.get("red_reflex", 0.0)),
                float(_age_group_to_numeric(payload.get("age_group", "unknown"))),
                float(payload.get("hirschberg", 0.0)),
            ]
        )
        labels.append(int(row.label))

    return np.asarray(features, dtype=np.float32), np.asarray(labels, dtype=np.int32)


def _build_model():
    inputs = Input(shape=(10,), name="clinical_input")
    x = Dense(64, activation="relu")(inputs)
    x = Dense(32, activation="relu")(x)
    outputs = Dense(4, activation="softmax")(x)
    model = Model(inputs=inputs, outputs=outputs)
    model.compile(
        optimizer=AdamW(learning_rate=1e-4),
        loss="categorical_crossentropy",
        metrics=["AUC"],
    )
    return model


def _export_tflite(model, output_path: Path):
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    tflite_model = converter.convert()
    output_path.write_bytes(tflite_model)


def _next_version(session) -> str:
    latest = session.query(ModelRegistry).order_by(ModelRegistry.created_at.desc()).first()
    if latest is None:
        return "1.0.0"
    major, minor, patch = [int(part) for part in latest.version.split(".")]
    return f"{major}.{minor}.{patch + 1}"


def _age_group_to_numeric(age_group: str) -> int:
    mapping = {
        "0-5": 3,
        "6-10": 8,
        "11-15": 13,
        "16-18": 17,
        "unknown": 0,
    }
    return mapping.get(age_group, 0)


def _safe_multiclass_auroc(y_true, y_pred):
    try:
        return roc_auc_score(tf.keras.utils.to_categorical(y_true, 4), y_pred, multi_class="ovr")
    except ValueError:
        return 0.0
