"""Pytest defaults — loaded before test modules."""
import os

os.environ.setdefault("MONGO_URL", os.environ.get("MONGO_URL", "mongodb://127.0.0.1:27017"))
os.environ.setdefault("DB_NAME", os.environ.get("DB_NAME", "ambyoai_pytest"))
os.environ.setdefault(
    "JWT_SECRET",
    os.environ.get("JWT_SECRET", "pytest-jwt-secret-key-at-least-32-characters-long!!"),
)
