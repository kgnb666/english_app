# core/config.py - 应用全局配置，通过 pydantic-settings 从 .env 读取

import logging
import secrets
from pathlib import Path
from typing import List

from pydantic_settings import BaseSettings

logger = logging.getLogger(__name__)

# backend/.env 绝对路径：无论从哪个目录启动都能加载
ENV_FILE = Path(__file__).resolve().parent.parent.parent / ".env"


class Settings(BaseSettings):
    """应用配置，自动从 .env 文件和环境变量加载"""

    # 应用
    APP_NAME: str = "AI English Coach"
    APP_VERSION: str = "0.1.0"
    DEBUG: bool = True

    # 数据库
    DATABASE_URL: str = "sqlite+aiosqlite:///./english_app.db"

    # JWT - 不提供固定默认值；必须通过环境变量或 .env 提供，为空时自动生成随机密钥
    SECRET_KEY: str = ""
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 120  # access token 短期有效（2 小时）
    REFRESH_TOKEN_EXPIRE_DAYS: int = 5  # refresh token 有效期 5 天

    # AI 模型
    AI_PROVIDER: str = "deepseek"  # "deepseek" 或 "openai"
    DEEPSEEK_API_KEY: str = ""
    DEEPSEEK_BASE_URL: str = "https://api.deepseek.com"
    DEEPSEEK_MODEL: str = "deepseek-chat"
    OPENAI_API_KEY: str = ""
    OPENAI_BASE_URL: str = "https://api.openai.com/v1"
    OPENAI_MODEL: str = "gpt-4o"

    # 语音转写：local（faster-whisper 本地免费） / siliconflow / openai
    WHISPER_PROVIDER: str = "local"
    WHISPER_MODEL: str = "models/whisper-base"
    WHISPER_API_KEY: str = ""
    WHISPER_BASE_URL: str = "https://api.siliconflow.cn/v1"
    WHISPER_MODEL_NAME: str = "openai/whisper-large-v3"

    # CORS
    CORS_ORIGINS: List[str] = ["*"]

    class Config:
        env_file = str(ENV_FILE)
        env_file_encoding = "utf-8"


settings = Settings()


def _ensure_secret_key() -> None:
    """SECRET_KEY 为空时生成随机密钥并持久化到 backend/.env，避免每次启动变化导致 token 失效"""
    if settings.SECRET_KEY:
        return
    generated = secrets.token_urlsafe(48)
    settings.SECRET_KEY = generated
    try:
        if ENV_FILE.exists():
            lines = ENV_FILE.read_text(encoding="utf-8").splitlines()
            replaced = False
            for i, line in enumerate(lines):
                if line.startswith("SECRET_KEY="):
                    lines[i] = f"SECRET_KEY={generated}"
                    replaced = True
                    break
            if not replaced:
                lines.append(f"SECRET_KEY={generated}")
            ENV_FILE.write_text("\n".join(lines) + "\n", encoding="utf-8")
        else:
            ENV_FILE.write_text(f"SECRET_KEY={generated}\n", encoding="utf-8")
        logger.warning("SECRET_KEY 未配置，已自动生成随机密钥并写入 %s", ENV_FILE)
    except OSError as e:
        logger.warning("自动写入 SECRET_KEY 失败（%s），本次运行使用内存随机密钥", e)


_ensure_secret_key()
