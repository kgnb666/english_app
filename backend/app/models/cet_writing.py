# models/cet_writing.py - 四六级作文模板与翻译训练

import uuid
from datetime import datetime

from sqlalchemy import Text, Integer, DateTime, ForeignKey, JSON, String, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.sqlite import VARCHAR

from app.models.base import Base


class WritingTemplate(Base):
    """个人作文模板库：用户常用模板 + AI 推荐模板"""
    __tablename__ = "writing_templates"

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("users.id"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(String(100), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[str | None] = mapped_column(
        String(50), nullable=True, comment="如 议论文 / 书信 / 图表"
    )
    is_ai_recommended: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user = relationship("User")


class CetTranslation(Base):
    """四六级翻译训练记录"""
    __tablename__ = "cet_translation"

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("users.id"), nullable=False, index=True
    )
    exam_type: Mapped[str] = mapped_column(String(10), nullable=False)
    chinese_text: Mapped[str] = mapped_column(Text, nullable=False)
    user_translation: Mapped[str] = mapped_column(Text, nullable=False)
    score: Mapped[int] = mapped_column(Integer, default=0)
    # AI 分析：词汇/语序/自然度/参考翻译
    analysis: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user = relationship("User")
