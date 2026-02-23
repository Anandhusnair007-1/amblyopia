"""
TFLite converter — converts a trained Keras/TF model to TFLite format
and uploads it to MinIO for deployment.
Run this script manually after model training:
  python -m ml.tflite_converter --model-path /path/to/model.h5 --version v1.0.0
"""
from __future__ import annotations

import argparse
import io
import logging
import sys

logger = logging.getLogger(__name__)


def convert_to_tflite(keras_model_path: str, output_path: str) -> bytes:
    """Convert a Keras .h5 model to TFLite optimized format."""
    import tensorflow as tf

    model = tf.keras.models.load_model(keras_model_path)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS,
    ]
    tflite_model = converter.convert()
    logger.info("Conversion done. Size: %.2f MB", len(tflite_model) / 1024 / 1024)
    return tflite_model


def upload_to_minio(model_bytes: bytes, version: str) -> str:
    """Upload TFLite model bytes to MinIO bucket."""
    import os
    from minio import Minio

    endpoint = os.environ.get("MINIO_ENDPOINT", "localhost:9000")
    access_key = os.environ.get("MINIO_ACCESS_KEY", "minioadmin")
    secret_key = os.environ.get("MINIO_SECRET_KEY", "minioadmin")
    bucket = os.environ.get("MINIO_BUCKET", "amblyopia")

    client = Minio(endpoint, access_key=access_key, secret_key=secret_key, secure=False)
    if not client.bucket_exists(bucket):
        client.make_bucket(bucket)

    object_name = f"models/{version}.tflite"
    client.put_object(
        bucket, object_name, io.BytesIO(model_bytes), length=len(model_bytes),
        content_type="application/octet-stream",
    )
    url = f"http://{endpoint}/{bucket}/{object_name}"
    logger.info("Uploaded: %s", url)
    return url


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    parser = argparse.ArgumentParser(description="Convert and upload TFLite model")
    parser.add_argument("--model-path", required=True, help="Path to Keras .h5 model")
    parser.add_argument("--version", required=True, help="Model version string e.g. v1.0.0")
    parser.add_argument("--output-path", default="/tmp/model.tflite", help="Local output path")
    args = parser.parse_args()

    tflite_bytes = convert_to_tflite(args.model_path, args.output_path)

    with open(args.output_path, "wb") as f:
        f.write(tflite_bytes)
    logger.info("Saved to: %s", args.output_path)

    url = upload_to_minio(tflite_bytes, args.version)
    logger.info("Ready for deployment at: %s", url)
