# models/profile.py - 用户学习画像模型

import uuid
from datetime import datetime

from sqlalchemy import Text, Integer, DateTime, ForeignKey, JSON, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.sqlite import VARCHAR

from app.models.base import Base


class UserProfile(Base):
    """用户学习画像 - 让 AI 了解用户的等级、目标、薄弱项与偏好"""
    __tablename__ = "user_profile"

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("users.id"), nullable=False, unique=True, index=True
    )
    english_level: Mapped[str] = mapped_column(VARCHAR(20), default="beginner")
    goal: Mapped[str | None] = mapped_column(
        Text, nullable=True, comment="学习目标，如：通过四级考试 / 日常英语交流"
    )
    vocabulary_size: Mapped[int] = mapped_column(Integer, default=0)
    # 薄弱技能数组，如 ["past_tense", "listening"]，由错误日志聚合 + 用户手动设置
    weak_skills: Mapped[list | None] = mapped_column(JSON, nullable=True)
    # 学习偏好，如 {"focus": ["口语"], "topics": ["科技"], "style": "轻松聊天"}
    preferences: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    user = relationship("User")


class UserErrorLog(Base):
    """用户错误记录 - 记录常犯错误，供 AI 针对性训练"""
    __tablename__ = "user_error_log"
    __table_args__ = (
        # 同一错误句子+类型只保留一条，用 count 累计出现次数
        UniqueConstraint(
            "user_id", "wrong_text", "error_type", name="uq_error_user_text_type"
        ),
    )

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("users.id"), nullable=False, index=True
    )
    wrong_text: Mapped[str] = mapped_column(Text, nullable=False, comment="用户错误句子")
    correct_text: Mapped[str] = mapped_column(Text, nullable=False, comment="正确表达")
    error_type: Mapped[str] = mapped_column(VARCHAR(50), default="other")
    error_type_cn: Mapped[str] = mapped_column(VARCHAR(50), default="其他错误")
    count: Mapped[int] = mapped_column(Integer, default=1)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user = relationship("User")
