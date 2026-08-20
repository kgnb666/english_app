# models/cet_coach.py - 四六级 AI 私人教练画像

import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.sqlite import VARCHAR

from app.models.base import Base


class CetAiProfile(Base):
    """AI 教练画像：弱项、错误类型、历史成绩、词汇掌握、最近建议"""
    __tablename__ = "cet_ai_profile"

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("users.id"), nullable=False, unique=True, index=True
    )
    weak_skills: Mapped[list | None] = mapped_column(JSON, nullable=True)
    error_types: Mapped[list | None] = mapped_column(JSON, nullable=True)
    exam_history: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    vocabulary_stats: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    last_suggestion: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    last_suggestion_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    user = relationship("User")
