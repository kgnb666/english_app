# models/vocabulary.py - 单词库与用户学习进度模型

import uuid
from datetime import date, datetime
from typing import Optional

from sqlalchemy import Text, Integer, Date, DateTime, ForeignKey, JSON, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.sqlite import VARCHAR

from app.models.base import Base
import enum


class DifficultyLevel(str, enum.Enum):
    EASY = "easy"
    MEDIUM = "medium"
    HARD = "hard"


class WordStatus(str, enum.Enum):
    NEW = "new"             # 新词，未学习
    LEARNING = "learning"   # 学习中
    REVIEW = "review"       # 待复习
    MASTERED = "mastered"   # 已掌握


class VocabularyWord(Base):
    """单词库 - 预置和用户创建的单词"""
    __tablename__ = "vocabulary_words"

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    word: Mapped[str] = mapped_column(VARCHAR(100), nullable=False, unique=True, index=True)
    phonetic: Mapped[Optional[str]] = mapped_column(VARCHAR(100), nullable=True)
    part_of_speech: Mapped[Optional[str]] = mapped_column(VARCHAR(20), nullable=True)
    chinese_definition: Mapped[str] = mapped_column(Text, nullable=False)
    example_sentences: Mapped[Optional[dict]] = mapped_column(
        JSON, nullable=True,
        comment="例句数组: [{en: '', cn: ''}]"
    )
    difficulty: Mapped[DifficultyLevel] = mapped_column(
        SAEnum(DifficultyLevel), default=DifficultyLevel.MEDIUM
    )
    category: Mapped[Optional[str]] = mapped_column(
        VARCHAR(50), nullable=True, comment="如 CET4, CET6, IELTS, TOEFL"
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class UserWordProgress(Base):
    """用户单词学习进度"""
    __tablename__ = "user_word_progress"

    id: Mapped[str] = mapped_column(
        VARCHAR(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("users.id"), nullable=False, index=True
    )
    word_id: Mapped[str] = mapped_column(
        VARCHAR(36), ForeignKey("vocabulary_words.id"), nullable=False
    )
    status: Mapped[WordStatus] = mapped_column(
        SAEnum(WordStatus), default=WordStatus.NEW
    )
    review_count: Mapped[int] = mapped_column(Integer, default=0)
    next_review_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    last_review_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    memory_aid: Mapped[Optional[str]] = mapped_column(
        Text, nullable=True, comment="AI 生成的记忆方法"
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # 关联
    user = relationship("User", back_populates="word_progress")
    word = relationship("VocabularyWord")
