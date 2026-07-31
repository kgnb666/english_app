# models/__init__.py - 导入所有模型，确保 Base.metadata 可发现所有表

from app.models.base import Base, engine, async_session_factory
from app.models.user import User, EnglishLevel
from app.models.chat import ChatSession, ChatMessage, MessageRole
from app.models.vocabulary import (
    VocabularyWord,
    UserWordProgress,
    DifficultyLevel,
    WordStatus,
)
from app.models.stats import DailyStats
