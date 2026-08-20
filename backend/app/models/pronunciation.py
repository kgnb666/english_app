# models/pronunciation.py - 发音评测记录模型

import uuid
from datetime import datetime

from sqlalchemy import Text, Integer, DateTime, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.sqlite import VARCHAR

from app.models.base import Base


class PronunciationRecord(Base):
    """发音评测记录 - 用户语音、评分、错误音节与建议"""
    __tablename__ = "pronunciation_records"

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("users.id"), nullable=False, index=True
    )
    target_text: Mapped[str] = mapped_column(Text, nullable=False, comment="目标句子")
    recognized_text: Mapped[str] = mapped_column(Text, nullable=False, comment="用户语音识别结果")
    score: Mapped[int] = mapped_column(Integer, default=0, comment="发音评分 0-100")
    # {"mispronounced_words": [...], "suggestions": [...], "overall_advice": "..."}
    result: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user = relationship("User")
