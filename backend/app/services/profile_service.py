# services/profile_service.py - 用户画像 + 错误记录服务

import re
from datetime import date, timedelta, datetime
from typing import Optional

from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.profile import UserProfile, UserErrorLog
from app.models.user import User
from app.models.stats import DailyStats

# 错误类型 -> 中文标签
ERROR_TYPE_CN = {
    "past_tense": "过去式错误",
    "tense": "时态错误",
    "agreement": "主谓一致",
    "article": "冠词错误",
    "preposition": "介词错误",
    "word_order": "语序错误",
    "pronoun": "代词错误",
    "plural": "单复数错误",
    "collocation": "搭配不当",
    "vocabulary": "用词不当",
    "spelling": "拼写错误",
    "punctuation": "标点错误",
    "missing_word": "漏词",
    "unnecessary_word": "多余词汇",
    "other": "其他错误",
}

# 按错误文本关键词推断错误类型（AI 未给出类型时的兜底）
_TYPE_RULES = [
    (("yesterday", "last ", " ago", "was", "were", "went", "did", "had", "said", "saw", "ate", "took", "got"), "past_tense"),
    (("a ", " an ", "the "), "article"),
    (("at ", " on ", " in ", "to ", "for ", "with ", "of "), "preposition"),
    (("i am ", "he ", "she ", "it ", "they "), "agreement"),
    (("ing", "ed", "will", "have", "has"), "tense"),
]


class ProfileService:

    def __init__(self, db: AsyncSession):
        self.db = db

    # ===== 画像读写 =====

    async def ensure_profile(self, user_id: str) -> UserProfile:
        """确保用户有画像记录，初始值同步 users 表等级"""
        r = await self.db.execute(select(UserProfile).where(UserProfile.user_id == user_id))
        profile = r.scalar_one_or_none()
        if profile:
            return profile
        user = (await self.db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
        level = user.english_level.value if user else "beginner"
        profile = UserProfile(
            user_id=user_id,
            english_level=level,
            weak_skills=[],
            preferences={"focus": [], "topics": []},
        )
        self.db.add(profile)
        await self.db.flush()
        await self.db.refresh(profile)
        return profile

    async def get_profile(self, user_id: str) -> dict:
        """返回用户画像（薄弱技能 = 手动设置 + 错误日志聚合）"""
        profile = await self.ensure_profile(user_id)
        error_skills = await self.get_error_summary(user_id)
        top_errors = [e["error_type"] for e in error_skills[:3]]
        manual = [s for s in (profile.weak_skills or []) if s not in top_errors]
        weak_skills = top_errors + manual
        return {
            "english_level": profile.english_level,
            "goal": profile.goal,
            "vocabulary_size": profile.vocabulary_size,
            "weak_skills": weak_skills,
            "preferences": profile.preferences or {},
            "common_errors": error_skills[:5],
            "updated_at": profile.updated_at.isoformat(),
        }

    async def update_profile(self, user_id: str, data: dict) -> dict:
        """更新画像；english_level 同步到 users 表"""
        profile = await self.ensure_profile(user_id)
        if "english_level" in data and data["english_level"]:
            level = data["english_level"]
            profile.english_level = level
            user = (await self.db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
            if user:
                user.english_level = level
        if "goal" in data and data["goal"] is not None:
            profile.goal = str(data["goal"]).strip() or None
        if "vocabulary_size" in data and data["vocabulary_size"] is not None:
            profile.vocabulary_size = max(0, int(data["vocabulary_size"]))
        if "weak_skills" in data and data["weak_skills"] is not None:
            profile.weak_skills = [str(s) for s in data["weak_skills"] if str(s).strip()]
        if "preferences" in data and data["preferences"] is not None:
            profile.preferences = data["preferences"] if isinstance(data["preferences"], dict) else {}
        await self.db.flush()
        return await self.get_profile(user_id)

    # ===== 错误记录 =====

    async def record_corrections(self, user_id: str, corrections: list[dict]) -> int:
        """把结构化纠错写入错误日志；相同错误句子+类型累计次数"""
        saved = 0
        for c in corrections:
            wrong = (c.get("wrong") or c.get("original") or "").strip()
            correct = (c.get("correct") or c.get("corrected") or "").strip()
            if not wrong or not correct:
                continue
            error_type = self._normalize_error_type(c.get("error_type") or "", wrong)
            error_type_cn = ERROR_TYPE_CN.get(error_type, "其他错误")
            r = await self.db.execute(
                select(UserErrorLog).where(
                    and_(
                        UserErrorLog.user_id == user_id,
                        UserErrorLog.wrong_text == wrong,
                        UserErrorLog.error_type == error_type,
                    )
                )
            )
            log = r.scalar_one_or_none()
            if log:
                log.count += 1
                log.correct_text = correct
                log.error_type_cn = error_type_cn
                log.last_seen_at = datetime.utcnow()
            else:
                self.db.add(UserErrorLog(
                    user_id=user_id,
                    wrong_text=wrong,
                    correct_text=correct,
                    error_type=error_type,
                    error_type_cn=error_type_cn,
                    count=1,
                    last_seen_at=datetime.utcnow(),
                ))
            saved += 1
        if saved:
            await self.db.flush()
        return saved

    async def get_error_log(self, user_id: str, limit: int = 50) -> list[dict]:
        r = await self.db.execute(
            select(UserErrorLog)
            .where(UserErrorLog.user_id == user_id)
            .order_by(UserErrorLog.count.desc(), UserErrorLog.last_seen_at.desc())
            .limit(min(max(limit, 1), 200))
        )
        return [
            {
                "id": e.id,
                "wrong_text": e.wrong_text,
                "correct_text": e.correct_text,
                "error_type": e.error_type,
                "error_type_cn": e.error_type_cn,
                "count": e.count,
                "last_seen_at": e.last_seen_at.isoformat(),
            }
            for e in r.scalars().all()
        ]

    async def get_error_summary(self, user_id: str) -> list[dict]:
        """按错误类型聚合，供画像/AI 上下文使用"""
        r = await self.db.execute(
            select(
                UserErrorLog.error_type,
                UserErrorLog.error_type_cn,
                func.sum(UserErrorLog.count).label("total"),
            )
            .where(UserErrorLog.user_id == user_id)
            .group_by(UserErrorLog.error_type, UserErrorLog.error_type_cn)
            .order_by(func.sum(UserErrorLog.count).desc())
        )
        return [
            {"error_type": row[0], "error_type_cn": row[1], "count": row[2]}
            for row in r.all()
        ]

    async def delete_error(self, user_id: str, error_id: str) -> None:
        r = await self.db.execute(
            select(UserErrorLog).where(
                UserErrorLog.id == error_id, UserErrorLog.user_id == user_id
            )
        )
        log = r.scalar_one_or_none()
        if not log:
            raise ValueError("Error log not found")
        await self.db.delete(log)
        await self.db.flush()

    # ===== AI 上下文 =====

    async def build_ai_context(self, user_id: str) -> dict:
        """构建 AI 个性化上下文：等级、目标、常犯错误、近期学习记录、偏好"""
        profile = await self.ensure_profile(user_id)
        user = (await self.db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
        level = profile.english_level or (user.english_level.value if user else "beginner")
        errors = await self.get_error_summary(user_id)
        recent = await self._recent_study(user_id)
        return {
            "level": level,
            "goal": profile.goal or "Improve overall English",
            "vocabulary_size": profile.vocabulary_size or 0,
            "common_errors": [
                {"type": e["error_type_cn"], "count": e["count"]} for e in errors[:5]
            ],
            "recent_study": recent,
            "preferences": profile.preferences or {},
        }

    async def _recent_study(self, user_id: str) -> dict:
        today = date.today()
        start = today - timedelta(days=6)
        r = await self.db.execute(
            select(
                func.sum(DailyStats.study_minutes),
                func.sum(DailyStats.words_learned),
                func.sum(DailyStats.words_reviewed),
                func.sum(DailyStats.reading_count),
                func.sum(DailyStats.writing_count),
                func.sum(DailyStats.ai_minutes),
            ).where(
                and_(
                    DailyStats.user_id == user_id,
                    DailyStats.date >= start,
                    DailyStats.date <= today,
                )
            )
        )
        row = r.one()
        return {
            "days": 7,
            "study_minutes": row[0] or 0,
            "words_learned": row[1] or 0,
            "words_reviewed": row[2] or 0,
            "reading_count": row[3] or 0,
            "writing_count": row[4] or 0,
            "ai_minutes": row[5] or 0,
        }

    # ===== 工具 =====

    @staticmethod
    def _normalize_error_type(raw: str, wrong_text: str) -> str:
        """规范化错误类型：优先 AI 给出的类型，其次按错误文本关键词推断"""
        value = (raw or "").strip().lower().replace(" ", "_").replace("-", "_")
        if value in ERROR_TYPE_CN:
            return value
        for key in ERROR_TYPE_CN:
            if key in value:
                return key
        text = wrong_text.lower()
        for keywords, etype in _TYPE_RULES:
            if any(kw in text for kw in keywords):
                return etype
        return "other"
