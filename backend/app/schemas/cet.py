# schemas/cet.py - 四六级学习请求模型

from datetime import date
from pydantic import BaseModel, Field


class CetGoalRequest(BaseModel):
    """设置四六级目标"""
    exam_type: str = Field(..., description="CET4 / CET6")
    target_score: int = Field(..., ge=425, le=710)
    exam_date: date
    daily_minutes: int = Field(30, ge=10, le=240)
