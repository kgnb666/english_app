# models/user.py - 用户模型

import uuid
from datetime import date, datetime

from sqlalchemy import String, Integer, Date, DateTime, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.sqlite import VARCHAR

from app.models.base import Base
import enum


class EnglishLevel(str, enum.Enum):
    """英语等级枚举"""
    BEGINNER = "beginner"
    ELEMENTARY = "elementary"
    INTERMEDIATE = "intermediate"
    UPPER_INTERMEDIATE = "upper_intermediate"
    ADVANCED = "advanced"


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    username: Mapped[str] = mapped_column(VARCHAR(50), unique=True, nullable=False, index=True)
    email: Mapped[str] = mapped_column(VARCHAR(100), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(VARCHAR(255), nullable=False)
    english_level: Mapped[EnglishLevel] = mapped_column(
        SAEnum(EnglishLevel), default=EnglishLevel.BEGINNER
    )
    daily_goal_minutes: Mapped[int] = mapped_column(Integer, default=30)
    daily_goal_words: Mapped[int] = mapped_column(Integer, default=20)
    streak_days: Mapped[int] = mapped_column(Integer, default=0)
    last_study_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(VARCHAR(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow
    )

    # 关联
    chat_sessions = relationship("ChatSession", back_populates="user", lazy="dynamic")
    word_progress = relationship("UserWordProgress", back_populates="user", lazy="dynamic")
    daily_stats = relationship("DailyStats", back_populates="user", lazy="dynamic")

    def __repr__(self):
        return f"<User(id={self.id}, username={self.username})>"
