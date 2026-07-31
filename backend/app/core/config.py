# core/config.py - 应用全局配置，通过 pydantic-settings 从 .env 读取

from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    """应用配置，自动从 .env 文件和环境变量加载"""

    # 应用
    APP_NAME: str = "AI English Coach"
    APP_VERSION: str = "0.1.0"
    DEBUG: bool = True

    # 数据库
    DATABASE_URL: str = "sqlite+aiosqlite:///./english_app.db"

    # JWT
    SECRET_KEY: str = "change-this-to-a-random-secret-key-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440  # 24 小时

    # AI 模型
    AI_PROVIDER: str = "deepseek"  # "deepseek" 或 "openai"
    DEEPSEEK_API_KEY: str = ""
    DEEPSEEK_BASE_URL: str = "https://api.deepseek.com"
    DEEPSEEK_MODEL: str = "deepseek-chat"
    OPENAI_API_KEY: str = ""
    OPENAI_BASE_URL: str = "https://api.openai.com/v1"
    OPENAI_MODEL: str = "gpt-4o"

    # CORS
    CORS_ORIGINS: List[str] = ["*"]

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
