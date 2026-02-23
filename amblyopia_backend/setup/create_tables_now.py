"""One-shot sync table creation — bypasses Alembic async hang."""
import os, sys
sys.path.insert(0, "/home/anandhu/projects/amblyopia_backend")
from dotenv import load_dotenv
load_dotenv()

db_url = os.getenv("DATABASE_URL", "").replace("postgresql+asyncpg://", "postgresql://")
print(f"Connecting to: {db_url[:60]}")

from sqlalchemy import create_engine, inspect
import app.models.audit_trail, app.models.combined_result
import app.models.doctor_review, app.models.gaze_result
import app.models.ml_model, app.models.notification_log
import app.models.nurse, app.models.patient
import app.models.redgreen_result, app.models.retraining_job
import app.models.session, app.models.snellen_result
import app.models.sync_queue, app.models.village
from app.database import Base

engine = create_engine(db_url, pool_pre_ping=True)
print("Creating all tables via Base.metadata.create_all ...")
Base.metadata.create_all(bind=engine)

tables = inspect(engine).get_table_names()
print(f"\nResult: {len(tables)} tables created")
for t in sorted(tables):
    print(f"  ✓ {t}")

if len(tables) >= 14:
    print("\nALL 14 TABLES CREATED SUCCESSFULLY")
else:
    print(f"\nWARNING: Only {len(tables)} tables found")
