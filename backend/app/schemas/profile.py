# schemas/profile.py - 用户画像相关 Pydantic 模型

from typing import Optional
from pydantic import BaseModel, Field


class ProfileUpdateRequest(BaseModel):
    """更新用户画像请求（所有字段可选）"""
    english_level: Optional[str] = None
    goal: Optional[str] = None
    vocabulary_size: Optional[int] = Field(None, ge=0)
    weak_skills: Optional[list[str]] = None
    preferences: Optional[dict] = None
