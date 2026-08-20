# models/cet.py - 四六级专项学习：目标与阶段计划

import uuid
from datetime import date, datetime

from sqlalchemy import Integer, Date, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.sqlite import VARCHAR

from app.models.base import Base


class CetGoal(Base):
    """四六级考试目标"""
    __tablename__ = "cet_goals"

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("users.id"), nullable=False, unique=True, index=True
    )
    exam_type: Mapped[str] = mapped_column(String(10), nullable=False)  # CET4 / CET6
    target_score: Mapped[int] = mapped_column(Integer, default=425)
    exam_date: Mapped[date] = mapped_column(Date, nullable=False)
    daily_minutes: Mapped[int] = mapped_column(Integer, default=30)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    user = relationship("User")


class CetStudyPlan(Base):
    """四六级阶段学习计划（每阶段一条）"""
    __tablename__ = "cet_study_plan"

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("users.id"), nullable=False, index=True
    )
    goal_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("cet_goals.id"), nullable=False, index=True
    )
    phase: Mapped[int] = mapped_column(Integer, nullable=False)  # 1-4
    phase_name: Mapped[str] = mapped_column(String(50), nullable=False)
    focus: Mapped[str] = mapped_column(String(100), nullable=False)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    daily_words: Mapped[int] = mapped_column(Integer, default=0)
    daily_reading: Mapped[int] = mapped_column(Integer, default=0)
    daily_listening_minutes: Mapped[int] = mapped_column(Integer, default=0)
    daily_writing_minutes: Mapped[int] = mapped_column(Integer, default=0)
    # done / active / upcoming
    status: Mapped[str] = mapped_column(String(20), default="upcoming")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user = relationship("User")
    goal = relationship("CetGoal")
