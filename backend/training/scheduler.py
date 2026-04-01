from apscheduler.schedulers.background import BackgroundScheduler

from training.train import run_training_pipeline

scheduler = BackgroundScheduler()
scheduler.add_job(
    run_training_pipeline,
    "cron",
    hour=2,
    minute=0,
    id="nightly_training",
    replace_existing=True,
)


def start_scheduler():
    if not scheduler.running:
        scheduler.start()
