"""
Airflow Model Deployment Plugin
Custom hook for marking a model as active in the database.
"""
from __future__ import annotations

from airflow.plugins_manager import AirflowPlugin
from airflow.hooks.base import BaseHook


class ModelDeploymentHook(BaseHook):
    """Custom hook to interact with the MLModel table for deployment status updates."""

    conn_name_attr = "postgres_conn_id"

    def deploy_model(self, version: str, tflite_path: str, accuracy: float) -> bool:
        """
        Mark a model version as active in ml_models table.
        Retire all previous active models.
        """
        import psycopg2
        import os

        db_url = os.environ.get(
            "DATABASE_URL", "postgresql://amblyopia:password@db:5432/amblyopia_db"
        ).replace("postgresql+asyncpg://", "postgresql://")

        conn = psycopg2.connect(db_url)
        cur = conn.cursor()
        try:
            cur.execute(
                """
                INSERT INTO ml_models (version, accuracy_score, tflite_file_path, status, deployed_at)
                VALUES (%s, %s, %s, 'active', NOW())
                ON CONFLICT (version) DO UPDATE SET status = 'active', deployed_at = NOW()
                """,
                (version, accuracy, tflite_path),
            )
            cur.execute(
                "UPDATE ml_models SET status = 'retired' WHERE status = 'active' AND version != %s",
                (version,),
            )
            conn.commit()
            return True
        except Exception as exc:
            conn.rollback()
            self.log.error("Failed to deploy model: %s", exc)
            return False
        finally:
            conn.close()


class ModelDeploymentPlugin(AirflowPlugin):
    name = "model_deployment_plugin"
    hooks = [ModelDeploymentHook]
