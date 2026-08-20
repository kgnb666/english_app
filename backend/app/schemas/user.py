# schemas/user.py - 用户相关 Pydantic 请求/响应模型

from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, Field


# ========== 认证相关 ==========

class UserRegisterRequest(BaseModel):
    """用户注册请求"""
    username: str = Field(..., min_length=2, max_length=50, description="用户名")
    email: EmailStr = Field(..., description="邮箱")
    password: str = Field(..., min_length=6, max_length=100, description="密码")


class UserLoginRequest(BaseModel):
    """用户登录请求"""
    username: str = Field(..., description="用户名")
    password: str = Field(..., description="密码")


class TokenResponse(BaseModel):
    """登录/注册成功后返回的 token"""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: str
    username: str


class RefreshRequest(BaseModel):
    """刷新令牌请求"""
    refresh_token: str = Field(..., min_length=1)


class LogoutRequest(BaseModel):
    """退出登录请求（注销刷新令牌）"""
    refresh_token: str = Field(..., min_length=1)


# ========== 用户信息 ==========

class UserProfileResponse(BaseModel):
    """用户个人信息响应"""
    id: str
    username: str
    email: str
    english_level: str
    daily_goal_minutes: int
    daily_goal_words: int
    streak_days: int
    last_study_date: Optional[date] = None
    avatar_url: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class UserUpdateRequest(BaseModel):
    """更新用户信息请求 (所有字段可选)"""
    english_level: Optional[str] = None
    daily_goal_minutes: Optional[int] = None
    daily_goal_words: Optional[int] = None
    avatar_url: Optional[str] = None
