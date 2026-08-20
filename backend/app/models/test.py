# models/test.py - 单词测试记录模型

import uuid
from datetime import datetime

from sqlalchemy import Text, Integer, DateTime, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.sqlite import VARCHAR

from app.models.base import Base


class TestRecord(Base):
    __tablename__ = "test_records"

    id: Mapped[str] = mapped_column(VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(VARCHAR(36), ForeignKey("users.id"), nullable=False, index=True)
    test_type: Mapped[str] = mapped_column(VARCHAR(20), nullable=False)  # choice/spelling/listening
    score: Mapped[int] = mapped_column(Integer, default=0)
    total: Mapped[int] = mapped_column(Integer, default=0)
    results: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
