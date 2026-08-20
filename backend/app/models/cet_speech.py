# models/cet_speech.py - 四六级听力与口语训练记录

import uuid
from datetime import datetime

from sqlalchemy import Text, Integer, DateTime, ForeignKey, JSON, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.sqlite import VARCHAR

from app.models.base import Base


class CetListeningRecord(Base):
    """四六级听力训练记录：音频、答案、正确率、AI 解析"""
    __tablename__ = "cet_listening_records"

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("users.id"), nullable=False, index=True
    )
    exam_type: Mapped[str] = mapped_column(String(10), nullable=False)
    item_id: Mapped[str] = mapped_column(String(40), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    audio_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    script: Mapped[str] = mapped_column(Text, nullable=False)
    questions: Mapped[list | None] = mapped_column(JSON, nullable=True)
    user_answers: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    score: Mapped[int] = mapped_column(Integer, default=0)
    total: Mapped[int] = mapped_column(Integer, default=0)
    # AI 逐句解析 + 生词解释
    analysis: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user = relationship("User")


class CetSpeakingRecord(Base):
    """四六级口语考试模拟记录"""
    __tablename__ = "cet_speaking_records"

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("users.id"), nullable=False, index=True
    )
    exam_type: Mapped[str] = mapped_column(String(10), nullable=False)
    question: Mapped[str] = mapped_column(Text, nullable=False)
    user_answer: Mapped[str] = mapped_column(Text, nullable=False)
    audio_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    score: Mapped[int] = mapped_column(Integer, default=0)
    # 四维评分：流利度/语法/词汇/发音 + 分析建议
    scores: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    analysis: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user = relationship("User")
