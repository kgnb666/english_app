# models/base.py - SQLAlchemy 引擎、会话工厂、基类

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from app.core.config import settings

# 异步数据库引擎
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,       # 开发环境打印 SQL
    future=True,
)

# 异步会话工厂
async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    """SQLAlchemy 声明式基类，所有模型继承自此"""
    pass
