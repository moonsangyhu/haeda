import logging
import os
from contextlib import asynccontextmanager

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.database import _get_session_factory
from app.exceptions import register_exception_handlers
from app.routers import auth, challenges, me, verifications
from app.services.scheduler_service import close_expired_challenges

logger = logging.getLogger(__name__)

scheduler = AsyncIOScheduler()


async def _run_close_expired_challenges():
    """APScheduler job wrapper — 자체 DB 세션으로 실행."""
    async with _get_session_factory()() as session:
        count = await close_expired_challenges(session)
        logger.info("scheduler job: close_expired_challenges → %d processed", count)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # startup
    scheduler.add_job(
        _run_close_expired_challenges,
        trigger=CronTrigger(hour=0, minute=0),
        id="close_expired_challenges",
        replace_existing=True,
    )
    scheduler.start()
    logger.info("Scheduler started — close_expired_challenges registered (daily midnight)")
    yield
    # shutdown
    if scheduler.running:
        scheduler.shutdown()
    logger.info("Scheduler shut down")


app = FastAPI(
    title="Haeda API",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# CORS 미들웨어 (개발 환경용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 예외 핸들러 등록
register_exception_handlers(app)

# 정적 파일 (업로드 사진) 서빙
_uploads_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "uploads")
os.makedirs(_uploads_dir, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=_uploads_dir), name="uploads")

# 라우터 등록
app.include_router(auth.router, prefix=settings.API_V1_PREFIX)
app.include_router(me.router, prefix=settings.API_V1_PREFIX)
app.include_router(challenges.router, prefix=settings.API_V1_PREFIX)
app.include_router(verifications.router, prefix=settings.API_V1_PREFIX)


@app.get("/health")
async def health_check():
    return {"status": "ok"}
