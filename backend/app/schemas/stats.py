# schemas/stats.py - 学习统计 Pydantic 模型

from datetime import date
from pydantic import BaseModel


class DailyStatsResponse(BaseModel):
    """每日统计响应"""
    date: date
    study_minutes: int
    study_seconds: int = 0
    words_learned: int
    words_reviewed: int
    chat_messages: int
    ai_minutes: int = 0
    reading_count: int = 0
    writing_count: int = 0

    class Config:
        from_attributes = True


class LearningSummaryResponse(BaseModel):
    """学习概览 - 首页仪表盘用"""
    total_days: int = 0           # 累计学习天数
    streak_days: int = 0          # 连续学习天数
    total_words_learned: int = 0  # 累计学习单词
    total_words_mastered: int = 0 # 已掌握单词
    today_minutes: int = 0        # 今日学习分钟
    today_words: int = 0          # 今日学习单词
    today_chat_messages: int = 0  # 今日对话消息数
    today_ai_minutes: int = 0     # 今日 AI 学习分钟
    today_reading_count: int = 0  # 今日阅读次数
    today_writing_count: int = 0  # 今日作文次数
