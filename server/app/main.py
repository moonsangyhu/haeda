import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.exceptions import register_exception_handlers
from app.routers import challenges, me, verifications

app = FastAPI(
    title="Haeda API",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
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
app.include_router(me.router, prefix=settings.API_V1_PREFIX)
app.include_router(challenges.router, prefix=settings.API_V1_PREFIX)
app.include_router(verifications.router, prefix=settings.API_V1_PREFIX)
# 다음 슬라이스에서 추가
# from app.routers import auth
# app.include_router(auth.router, prefix=settings.API_V1_PREFIX)


@app.get("/health")
async def health_check():
    return {"status": "ok"}
