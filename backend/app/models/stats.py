# models/stats.py - 每日学习统计模型

import uuid
from datetime import date, datetime

from sqlalchemy import Integer, Date, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.sqlite import VARCHAR

from app.models.base import Base


class DailyStats(Base):
    """每日学习统计 - 按天记录用户学习数据"""
    __tablename__ = "daily_stats"

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("users.id"), nullable=False, index=True
    )
    date: Mapped[date] = mapped_column(Date, nullable=False)
    study_minutes: Mapped[int] = mapped_column(Integer, default=0)
    study_seconds: Mapped[int] = mapped_column(Integer, default=0)
    words_learned: Mapped[int] = mapped_column(Integer, default=0)
    words_reviewed: Mapped[int] = mapped_column(Integer, default=0)
    chat_messages: Mapped[int] = mapped_column(Integer, default=0)
    ai_minutes: Mapped[int] = mapped_column(Integer, default=0)
    reading_count: Mapped[int] = mapped_column(Integer, default=0)
    writing_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # 关联
    user = relationship("User", back_populates="daily_stats")
