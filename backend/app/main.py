# main.py - FastAPI application entry point

import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.config import settings
from app.models.base import engine, Base
from app.api.v1.auth import router as auth_router
from app.api.v1.chat import router as chat_router
from app.api.v1.vocabulary import router as vocabulary_router
from app.api.v1.stats import router as stats_router
from app.api.v1.reading import router as reading_router
from app.api.v1.writing import router as writing_router
from app.api.v1.backup import router as backup_router
from app.api.v1.plan import router as plan_router
from app.api.v1.profile import router as profile_router
from app.api.v1.pronunciation import router as pronunciation_router
from app.api.v1.tts import router as tts_router
from app.api.v1.speech import router as speech_router
from app.api.v1.cet import router as cet_router
from app.api.v1.cet_reading import router as cet_reading_router
from app.api.v1.cet_writing import router as cet_writing_router
from app.api.v1.cet_translation import router as cet_translation_router
from app.api.v1.cet_listening import router as cet_listening_router
from app.api.v1.cet_speaking import router as cet_speaking_router
from app.api.v1.cet_coach import router as cet_coach_router

logger = logging.getLogger("app.error")

# 错误码映射
HTTP_ERROR_CODES = {
    400: "BAD_REQUEST",
    401: "UNAUTHORIZED",
    403: "FORBIDDEN",
    404: "NOT_FOUND",
    409: "CONFLICT",
    422: "UNPROCESSABLE_ENTITY",
}


@asynccontextmanager
async def lifespan(app: FastAPI):
    import app.models
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        from app.core.schema import ensure_schema
        await ensure_schema(conn)
    yield
    await engine.dispose()


app = FastAPI(title=settings.APP_NAME, version=settings.APP_VERSION, description="AI English Learning Assistant", lifespan=lifespan)


@app.exception_handler(ValueError)
async def value_error_handler(request: Request, exc: ValueError):
    """业务层 ValueError -> 400，统一返回错误码与错误信息"""
    return JSONResponse(
        status_code=400,
        content={"code": "VALIDATION_ERROR", "message": str(exc), "detail": str(exc)},
    )


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError):
    """请求参数校验失败 -> 422，统一错误码"""
    message = "请求参数不正确"
    try:
        first = exc.errors()[0]
        loc = ".".join(str(x) for x in first.get("loc", []))
        message = f"{loc}: {first.get('msg', 'invalid')}" if loc else first.get("msg", message)
    except Exception:
        pass
    return JSONResponse(
        status_code=422,
        content={"code": "VALIDATION_ERROR", "message": message, "detail": message},
    )


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    """HTTPException -> 保留状态码，统一错误码结构"""
    code = HTTP_ERROR_CODES.get(exc.status_code, "HTTP_ERROR")
    message = exc.detail if isinstance(exc.detail, dict) else str(exc.detail)
    return JSONResponse(
        status_code=exc.status_code,
        content={"code": code, "message": message, "detail": message},
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    """未捕获异常 -> 500，生产环境不泄露堆栈"""
    logger.exception("Unhandled error on %s %s", request.method, request.url.path)
    content = {"code": "INTERNAL_ERROR", "message": "服务器内部错误，请稍后重试"}
    if settings.DEBUG:
        content["detail"] = str(exc)
    return JSONResponse(status_code=500, content=content)

app.add_middleware(CORSMiddleware, allow_origins=settings.CORS_ORIGINS, allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

# 静态音频资源（词库固定音频）
STATIC_DIR = Path(__file__).resolve().parent.parent / "static"
STATIC_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

app.include_router(auth_router, prefix="/api/v1")
app.include_router(chat_router, prefix="/api/v1")
app.include_router(vocabulary_router, prefix="/api/v1")
app.include_router(stats_router, prefix="/api/v1")
app.include_router(reading_router, prefix="/api/v1")
app.include_router(writing_router, prefix="/api/v1")
app.include_router(backup_router, prefix="/api/v1")
app.include_router(plan_router, prefix="/api/v1")
app.include_router(profile_router, prefix="/api/v1")
app.include_router(pronunciation_router, prefix="/api/v1")
app.include_router(tts_router, prefix="/api/v1")
app.include_router(speech_router, prefix="/api/v1")
app.include_router(cet_router, prefix="/api/v1")
app.include_router(cet_reading_router, prefix="/api/v1")
app.include_router(cet_writing_router, prefix="/api/v1")
app.include_router(cet_translation_router, prefix="/api/v1")
app.include_router(cet_listening_router, prefix="/api/v1")
app.include_router(cet_speaking_router, prefix="/api/v1")
app.include_router(cet_coach_router, prefix="/api/v1")


@app.get("/")
async def root():
    return {"app": settings.APP_NAME, "version": settings.APP_VERSION, "status": "running"}


@app.get("/health")
async def health():
    return {"status": "healthy"}
