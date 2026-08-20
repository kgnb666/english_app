# schemas/vocabulary.py - 单词相关 Pydantic 模型

from datetime import date, datetime
from typing import Any, Optional
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
    exam_type: Optional[str] = None
    word_level: Optional[str] = None
    audio_url: Optional[str] = None

    class Config:
        from_attributes = True


class UserWordProgressResponse(BaseModel):
    """用户单词学习进度响应"""
    id: str
    word_id: str
    word: Optional[VocabularyWordResponse] = None
    status: str
    review_count: int
    repetition: int = 0
    ease_factor: float = 2.5
    error_count: int = 0
    is_bookmarked: bool = False
    next_review_date: Optional[date] = None
    last_review_date: Optional[date] = None
    memory_aid: Optional[str] = None

    class Config:
        from_attributes = True


class MemoryAidRequest(BaseModel):
    """请求 AI 生成记忆方法"""
    word_id: str = Field(..., description="单词 ID")


class SeedWordItem(BaseModel):
    """批量导入的单个单词，兼容多种字段命名"""
    word: str = Field(..., min_length=1, max_length=100, description="单词")
    phonetic: Optional[str] = None
    part_of_speech: Optional[str] = None
    pos: Optional[str] = None
    meaning: Optional[str] = None
    chinese_definition: Optional[str] = None
    translation: Optional[str] = None
    example: Optional[Any] = None
    example_sentences: Optional[Any] = None
    difficulty: Optional[str] = None
    category: Optional[str] = None


class SeedWordsRequest(BaseModel):
    """批量导入单词请求体"""
    words: list[SeedWordItem] = Field(..., min_length=1, description="单词列表")
