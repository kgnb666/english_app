# models/chat.py - 对话会话与消息模型

import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import Text, Integer, DateTime, ForeignKey, JSON, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.sqlite import VARCHAR

from app.models.base import Base
import enum


class MessageRole(str, enum.Enum):
    USER = "user"
    ASSISTANT = "assistant"
    SYSTEM = "system"


class ChatSession(Base):
    __tablename__ = "chat_sessions"

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("users.id"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(VARCHAR(200), default="New Conversation")
    topic: Mapped[Optional[str]] = mapped_column(VARCHAR(100), nullable=True)
    message_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    # 关联
    user = relationship("User", back_populates="chat_sessions")
    messages = relationship(
        "ChatMessage",
        back_populates="session",
        lazy="dynamic",
        order_by="ChatMessage.created_at",
    )


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    session_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("chat_sessions.id"), nullable=False, index=True
    )
    role: Mapped[MessageRole] = mapped_column(
        SAEnum(MessageRole), nullable=False
    )
    content: Mapped[str] = mapped_column(Text, nullable=False)
    grammar_corrections: Mapped[Optional[dict]] = mapped_column(
        JSON, nullable=True,
        comment="AI 语法纠错数据: {original, corrected, explanation}"
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # 关联
    session = relationship("ChatSession", back_populates="messages")
