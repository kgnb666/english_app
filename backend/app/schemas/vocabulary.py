# schemas/vocabulary.py - 单词相关 Pydantic 模型

from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel, Field


class VocabularyWordResponse(BaseModel):
    """单词详情响应"""
    id: str
    word: str
    phonetic: Optional[str] = None
    part_of_speech: Optional[str] = None
    chinese_definition: str
    example_sentences: Optional[list] = None
    difficulty: str
    category: Optional[str] = None

    class Config:
        from_attributes = True


class UserWordProgressResponse(BaseModel):
    """用户单词学习进度响应"""
    id: str
    word_id: str
    word: Optional[VocabularyWordResponse] = None
    status: str
    review_count: int
    next_review_date: Optional[date] = None
    last_review_date: Optional[date] = None
    memory_aid: Optional[str] = None

    class Config:
        from_attributes = True


class MemoryAidRequest(BaseModel):
    """请求 AI 生成记忆方法"""
    word_id: str = Field(..., description="单词 ID")
