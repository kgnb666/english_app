# models/cet_reading.py - 四六级阅读训练记录

import uuid
from datetime import datetime

from sqlalchemy import Text, Integer, DateTime, ForeignKey, JSON, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.sqlite import VARCHAR

from app.models.base import Base


class CetReadingRecord(Base):
    """四六级阅读训练记录：文章、题目、答案、AI 分析"""
    __tablename__ = "cet_reading_records"

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("users.id"), nullable=False, index=True
    )
    exam_type: Mapped[str] = mapped_column(String(10), nullable=False)  # CET4 / CET6
    article_id: Mapped[str] = mapped_column(String(40), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    article: Mapped[str] = mapped_column(Text, nullable=False)
    questions: Mapped[list | None] = mapped_column(JSON, nullable=True)
    user_answers: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    score: Mapped[int] = mapped_column(Integer, default=0)
    total: Mapped[int] = mapped_column(Integer, default=0)
    # AI 分析：每题原因/陷阱、长难句、生词
    analysis: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user = relationship("User")
