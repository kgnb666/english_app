# services/cet_coach_service.py - 四六级 AI 私人教练

import json
import re
from datetime import date
from typing import Optional

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cet_coach import CetAiProfile
from app.models.cet import CetGoal
from app.models.cet_reading import CetReadingRecord
from app.models.cet_speech import CetListeningRecord, CetSpeakingRecord
from app.models.cet_writing import CetTranslation
from app.models.vocabulary import UserWordProgress, WordStatus
from app.models.profile import UserErrorLog
from app.ai.client import ai_client
from app.ai.prompts import CET_COACH_PROMPT
from app.services.plan_service import PlanService


class CetCoachService:

    def __init__(self, db: AsyncSession):
        self.db = db

    # ===== 画像聚合 =====

    async def build_profile(self, user_id: str) -> dict:
        """聚合真实学习数据生成教练画像"""
        # 历史成绩：各模块最近 5 条平均正确率
        reading = await self._avg_accuracy(CetReadingRecord, user_id)
        listening = await self._avg_accuracy(CetListeningRecord, user_id)
        translation = await self._avg_accuracy(CetTranslation, user_id, max_score=10)
        speaking = await self._avg_speaking(user_id)
        exam_history = {
            "reading": reading,
            "listening": listening,
            "translation": translation,
            "speaking": speaking,
        }
        # 弱项：正确率 < 60 的模块
        weak_skills = [
            name for name, v in exam_history.items()
            if v is not None and v < 60
        ]
        # 错误类型：纠错日志 top
        err = await self.db.execute(
            select(UserErrorLog.error_type_cn, func.sum(UserErrorLog.count))
            .where(UserErrorLog.user_id == user_id)
            .group_by(UserErrorLog.error_type_cn)
            .order_by(func.sum(UserErrorLog.count).desc())
            .limit(5)
        )
        error_types = [{"type": row[0], "count": row[1]} for row in err.all()]
        # 词汇掌握
        r = await self.db.execute(
            select(UserWordProgress.status, func.count())
            .where(UserWordProgress.user_id == user_id)
            .group_by(UserWordProgress.status)
        )
        status_map = {row[0].value: row[1] for row in r.all()}
        vocabulary_stats = {
            "total": sum(status_map.values()),
            "mastered": status_map.get(WordStatus.MASTERED.value, 0),
            "learning": status_map.get(WordStatus.LEARNING.value, 0),
            "review": status_map.get(WordStatus.REVIEW.value, 0),
            "new": status_map.get(WordStatus.NEW.value, 0),
        }
        return {
            "weak_skills": weak_skills,
            "error_types": error_types,
            "exam_history": exam_history,
            "vocabulary_stats": vocabulary_stats,
        }

    async def get_profile(self, user_id: str) -> dict:
        profile = await self.build_profile(user_id)
        goal = (await self.db.execute(select(CetGoal).where(CetGoal.user_id == user_id))).scalar_one_or_none()
        rec = await self._ensure_profile(user_id)
        rec.weak_skills = profile["weak_skills"]
        rec.error_types = profile["error_types"]
        rec.exam_history = profile["exam_history"]
        rec.vocabulary_stats = profile["vocabulary_stats"]
        await self.db.flush()
        profile["goal"] = {
            "exam_type": goal.exam_type,
            "target_score": goal.target_score,
            "days_left": (goal.exam_date - date.today()).days,
        } if goal else None
        profile["last_suggestion"] = rec.last_suggestion
        return profile

    # ===== 每日建议 =====

    async def get_daily_suggestion(self, user_id: str) -> dict:
        rec = await self._ensure_profile(user_id)
        # 当日缓存
        if rec.last_suggestion and rec.last_suggestion_date == date.today():
            return rec.last_suggestion
        profile = await self.build_profile(user_id)
        goal = (await self.db.execute(select(CetGoal).where(CetGoal.user_id == user_id))).scalar_one_or_none()
        today_tasks = await PlanService(self.db).get_today_tasks(user_id)
        suggestion = await self._suggest_with_ai(user_id, profile, goal, today_tasks)
        rec.last_suggestion = suggestion
        rec.last_suggestion_date = date.today()
        await self.db.flush()
        return suggestion

    async def _suggest_with_ai(
        self, user_id: str, profile: dict, goal: Optional[CetGoal], today_tasks: dict
    ) -> dict:
        goal_info = {
            "exam_type": goal.exam_type,
            "target_score": goal.target_score,
            "days_left": (goal.exam_date - date.today()).days,
        } if goal else None
        prompt = CET_COACH_PROMPT.format(
            profile=json.dumps(profile, ensure_ascii=False),
            goal=json.dumps(goal_info, ensure_ascii=False),
            today_tasks=json.dumps(today_tasks, ensure_ascii=False),
        )
        try:
            reply = await ai_client.chat(
                messages=[{"role": "user", "content": prompt}],
                temperature=0.5,
                max_tokens=1200,
                json_mode=True,
            )
            parsed = self._parse_json(reply)
        except Exception as e:
            print(f"CetCoach AI error: {e}")
            return self._fallback_suggestion(profile, goal)
        if parsed:
            suggestion = {
                "summary": str(parsed.get("summary") or ""),
                "suggestions": [
                    {
                        "title": str(s.get("title") or ""),
                        "detail": str(s.get("detail") or ""),
                        "reason": str(s.get("reason") or ""),
                    }
                    for s in parsed.get("suggestions") or []
                    if isinstance(s, dict)
                ],
            }
            adjustment = parsed.get("plan_adjustment")
            if isinstance(adjustment, dict) and goal:
                try:
                    await self._apply_plan_adjustment(user_id, adjustment)
                    suggestion["plan_adjusted"] = True
                except Exception as e:
                    print(f"CetCoach plan adjust error: {e}")
                    suggestion["plan_adjusted"] = False
            else:
                suggestion["plan_adjusted"] = False
            return suggestion
        return self._fallback_suggestion(profile, goal)

    async def _apply_plan_adjustment(self, user_id: str, adjustment: dict) -> None:
        plan = {
            "words": max(0, int(adjustment.get("words") or 0)),
            "reading": max(0, int(adjustment.get("reading") or 0)),
            "ai_minutes": max(0, int(adjustment.get("ai_minutes") or 0)),
            "writing": max(0, int(adjustment.get("writing") or 0)),
        }
        await PlanService(self.db).update_plan(user_id, [
            {"task_type": t, "target_count": plan[t], "enabled": plan[t] > 0}
            for t in plan
        ])

    @staticmethod
    def _fallback_suggestion(profile: dict, goal: Optional[CetGoal]) -> dict:
        """AI 不可用时按弱项生成规则建议"""
        weak = profile.get("weak_skills") or []
        suggestions = []
        if "reading" in weak:
            suggestions.append({"title": "加强阅读训练", "detail": "完成 2 篇阅读并复盘错题", "reason": "阅读正确率偏低"})
        elif "listening" in weak:
            suggestions.append({"title": "精听训练", "detail": "完成 1 篇听力精听并跟读", "reason": "听力正确率偏低"})
        elif "translation" in weak:
            suggestions.append({"title": "翻译练习", "detail": "完成 3 句汉译英并对照参考译文", "reason": "翻译评分偏低"})
        if not suggestions:
            suggestions.append({"title": "保持词汇复习", "detail": "按今日任务完成单词学习", "reason": "保持学习节奏"})
        suggestions.append({"title": "复盘常犯错误", "detail": "重看近期纠错记录，避免重复犯错", "reason": "错误类型持续积累"})
        goal_text = (
            f"距{goal.exam_type}考试 {(goal.exam_date - date.today()).days} 天"
            if goal else "按四六级计划稳步推进"
        )
        return {
            "summary": f"今天专注薄弱模块，{goal_text}。",
            "suggestions": suggestions,
            "plan_adjusted": False,
        }

    # ===== 工具 =====

    async def _ensure_profile(self, user_id: str) -> CetAiProfile:
        r = await self.db.execute(select(CetAiProfile).where(CetAiProfile.user_id == user_id))
        rec = r.scalar_one_or_none()
        if not rec:
            rec = CetAiProfile(user_id=user_id)
            self.db.add(rec)
            await self.db.flush()
            await self.db.refresh(rec)
        return rec

    async def _avg_accuracy(self, model, user_id: str, max_score: Optional[int] = None) -> Optional[int]:
        expr = (
            model.score * 100.0 / max_score
            if max_score is not None
            else model.score * 100.0 / model.total
        )
        r = await self.db.execute(
            select(func.avg(expr)).where(
                model.user_id == user_id,
                (model.total > 0) if max_score is None else model.score > 0,
            )
        )
        val = r.scalar()
        return round(val) if val is not None else None

    async def _avg_speaking(self, user_id: str) -> Optional[int]:
        r = await self.db.execute(
            select(func.avg(CetSpeakingRecord.score * 5.0))
            .where(CetSpeakingRecord.user_id == user_id)
        )
        val = r.scalar()
        return round(val) if val is not None else None

    @staticmethod
    def _parse_json(text: str) -> Optional[dict]:
        if not text:
            return None
        cleaned = text.strip()
        if cleaned.startswith("```"):
            cleaned = re.sub(r"^```[a-zA-Z]*\n?", "", cleaned)
            cleaned = re.sub(r"\n?```$", "", cleaned)
        try:
            data = json.loads(cleaned)
            return data if isinstance(data, dict) else None
        except json.JSONDecodeError:
            pass
        m = re.search(r"\{.*\}", cleaned, re.DOTALL)
        if m:
            try:
                data = json.loads(m.group())
                return data if isinstance(data, dict) else None
            except json.JSONDecodeError:
                return None
        return None
