# models/history.py - 阅读和作文历史记录模型

import uuid
from datetime import datetime

from sqlalchemy import Text, Integer, DateTime, ForeignKey, JSON, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.sqlite import VARCHAR

from app.models.base import Base


class ReadingRecord(Base):
    __tablename__ = "reading_records"

    id: Mapped[str] = mapped_column(VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(VARCHAR(36), ForeignKey("users.id"), nullable=False, index=True)
    article_content: Mapped[str] = mapped_column(Text, nullable=False)
    analysis_result: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user = relationship("User")


class WritingRecord(Base):
    __tablename__ = "writing_records"

    id: Mapped[str] = mapped_column(VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(VARCHAR(36), ForeignKey("users.id"), nullable=False, index=True)
    exam_type: Mapped[str | None] = mapped_column(
        String(10), nullable=True, comment="CET4 / CET6（四六级作文训练）"
    )
    original_text: Mapped[str] = mapped_column(Text, nullable=False)
    score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    correction_result: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user = relationship("User")
