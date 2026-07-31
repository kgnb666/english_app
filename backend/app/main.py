# main.py - FastAPI 应用入口

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.models.base import engine, Base
from app.api.v1.auth import router as auth_router
from app.api.v1.chat import router as chat_router
from app.api.v1.vocabulary import router as vocabulary_router
from app.api.v1.stats import router as stats_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期：启动时创建数据库表，关闭时释放连接"""
    # 导入所有模型，确保 Base.metadata 包含所有表
    import app.models  # noqa: F401

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="AI 英语学习助手 - 私人英语教练 API",
    lifespan=lifespan,
)

# CORS 中间件 - 允许移动端和前端跨域访问
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.include_router(auth_router, prefix="/api/v1")
app.include_router(chat_router, prefix="/api/v1")
app.include_router(vocabulary_router, prefix="/api/v1")
app.include_router(stats_router, prefix="/api/v1")


@app.get("/")
async def root():
    """根路由 - 健康检查"""
    return {
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "running",
    }


@app.get("/health")
async def health():
    """健康检查端点"""
    return {"status": "healthy"}
