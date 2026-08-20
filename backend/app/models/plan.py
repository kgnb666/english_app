# models/plan.py - 学习计划与每日任务模型

import uuid
from datetime import date, datetime

from sqlalchemy import Integer, Date, DateTime, ForeignKey, String, UniqueConstraint, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.sqlite import VARCHAR

from app.models.base import Base


class LearningPlan(Base):
    """学习计划 - 用户的任务模板（每日按此生成任务）"""
    __tablename__ = "learning_plan"
    __table_args__ = (UniqueConstraint("user_id", "task_type", name="uq_plan_user_type"),)

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("users.id"), nullable=False, index=True
    )
    # words / ai_minutes / reading / writing
    task_type: Mapped[str] = mapped_column(String(20), nullable=False)
    target_count: Mapped[int] = mapped_column(Integer, default=0)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    user = relationship("User")


class DailyTask(Base):
    """每日任务 - 每天自动生成，完成状态来自真实学习数据"""
    __tablename__ = "daily_tasks"
    __table_args__ = (UniqueConstraint("user_id", "task_date", "task_type", name="uq_task_user_date_type"),)

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("users.id"), nullable=False, index=True
    )
    task_date: Mapped[date] = mapped_column(Date, nullable=False)
    task_type: Mapped[str] = mapped_column(String(20), nullable=False)
    target_count: Mapped[int] = mapped_column(Integer, default=0)
    completed_count: Mapped[int] = mapped_column(Integer, default=0)
    # pending / completed
    status: Mapped[str] = mapped_column(String(20), default="pending", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    user = relationship("User")
