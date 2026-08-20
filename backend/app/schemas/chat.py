# schemas/chat.py - 对话相关 Pydantic 模型

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class ChatMessageRequest(BaseModel):
    """发送消息请求"""
    content: str = Field(..., min_length=1, description="用户消息内容")


class GrammarCorrection(BaseModel):
    """语法纠错数据"""
    original: str = ""
    corrected: str = ""
    explanation: str = ""


class ChatMessageResponse(BaseModel):
    """消息响应"""
    id: str
    session_id: str
    role: str
    content: str
    grammar_corrections: Optional[dict] = None
    metadata: Optional[dict] = None
    created_at: datetime

    class Config:
        from_attributes = True


class ChatSessionResponse(BaseModel):
    """会话列表项"""
    id: str
    title: str
    topic: Optional[str] = None
    message_count: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ChatSessionDetailResponse(BaseModel):
    """会话详情 (含消息列表)"""
    id: str
    title: str
    topic: Optional[str] = None
    messages: list[ChatMessageResponse]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
