# services/cet_service.py - 四六级专项学习服务

from datetime import date, timedelta
from typing import Optional

from sqlalchemy import select, and_, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cet import CetGoal, CetStudyPlan
from app.models.user import User
from app.services.plan_service import PlanService, DEFAULT_PLAN

EXAM_TYPES = ("CET4", "CET6")

# 四个阶段：名称、重点、每日目标（按目标分数强弱）
PHASE_TEMPLATE = [
    {"phase_name": "词汇突破", "focus": "高频核心词 + 真题词汇", "words": (30, 40)},
    {"phase_name": "阅读提升", "focus": "阅读理解 + 长难句", "words": (20, 20), "reading": (2, 3)},
    {"phase_name": "听力训练", "focus": "听力精听 + 口语跟读", "words": (20, 20), "reading": (1, 1), "listening": (15, 20)},
    {"phase_name": "作文翻译", "focus": "写作模板 + 翻译练习", "words": (20, 20), "reading": (1, 1), "listening": (10, 15), "writing_minutes": (15, 20)},
]

# 阶段天数权重
PHASE_WEIGHTS = [0.40, 0.25, 0.20, 0.15]


class CetService:

    def __init__(self, db: AsyncSession):
        self.db = db

    # ===== 目标设置 =====

    async def set_goal(
        self,
        user_id: str,
        exam_type: str,
        target_score: int,
        exam_date: date,
        daily_minutes: int,
    ) -> dict:
        exam_type = exam_type.upper()
        if exam_type not in EXAM_TYPES:
            raise ValueError("exam_type must be CET4 or CET6")
        if not 425 <= target_score <= 710:
            raise ValueError("target_score must be between 425 and 710")
        if exam_date <= date.today():
            raise ValueError("exam_date must be in the future")
        daily_minutes = max(10, min(int(daily_minutes), 240))

        r = await self.db.execute(select(CetGoal).where(CetGoal.user_id == user_id))
        goal = r.scalar_one_or_none()
        if not goal:
            goal = CetGoal(user_id=user_id)
            self.db.add(goal)
        goal.exam_type = exam_type
        goal.target_score = int(target_score)
        goal.exam_date = exam_date
        goal.daily_minutes = daily_minutes
        await self.db.flush()

        await self._regenerate_plan(user_id, goal)
        return await self.get_dashboard(user_id)

    async def cancel_goal(self, user_id: str) -> dict:
        """取消四六级目标，恢复默认学习计划"""
        await self.db.execute(delete(CetStudyPlan).where(CetStudyPlan.user_id == user_id))
        await self.db.execute(delete(CetGoal).where(CetGoal.user_id == user_id))
        await self.db.flush()
        # 恢复默认每日任务模板
        user = (await self.db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
        defaults = dict(DEFAULT_PLAN)
        if user:
            defaults["words"] = user.daily_goal_words or 30
            defaults["ai_minutes"] = user.daily_goal_minutes or 20
        await PlanService(self.db).update_plan(user_id, [
            {"task_type": t, "target_count": defaults[t], "enabled": defaults[t] > 0}
            for t in DEFAULT_PLAN
        ])
        return {"goal": None}

    # ===== 计划生成 =====

    async def _regenerate_plan(self, user_id: str, goal: CetGoal) -> None:
        """按剩余天数 + 目标分数生成 4 阶段计划，并同步每日任务模板"""
        await self.db.execute(delete(CetStudyPlan).where(CetStudyPlan.goal_id == goal.id))
        total_days = (goal.exam_date - date.today()).days
        strong = goal.target_score >= 500
        cursor = date.today()
        phases = []
        for i, tpl in enumerate(PHASE_TEMPLATE):
            days = max(1, round(total_days * PHASE_WEIGHTS[i]))
            if i == len(PHASE_TEMPLATE) - 1:
                days = max(1, (goal.exam_date - cursor).days)
            end = min(cursor + timedelta(days=days - 1), goal.exam_date)
            def _pick(key, default=0):
                v = tpl.get(key)
                return (v[1] if strong else v[0]) if v else default
            phases.append(CetStudyPlan(
                user_id=user_id,
                goal_id=goal.id,
                phase=i + 1,
                phase_name=tpl["phase_name"],
                focus=tpl["focus"],
                start_date=cursor,
                end_date=end,
                daily_words=_pick("words"),
                daily_reading=_pick("reading"),
                daily_listening_minutes=_pick("listening"),
                daily_writing_minutes=_pick("writing_minutes"),
            ))
            self.db.add(phases[-1])
            cursor = end + timedelta(days=1)
            if cursor > goal.exam_date:
                break
        await self.db.flush()
        # 同步每日任务模板到当前阶段
        await self._sync_daily_tasks(user_id, date.today())

    async def _sync_daily_tasks(self, user_id: str, day: date) -> None:
        """把当前阶段的每日目标写入 learning_plan，首页任务自动跟随"""
        current = await self._current_phase(user_id, day)
        if not current:
            return
        writing_tasks = 1 if current.daily_writing_minutes > 0 else 0
        await PlanService(self.db).update_plan(user_id, [
            {"task_type": "words", "target_count": current.daily_words, "enabled": current.daily_words > 0},
            {"task_type": "reading", "target_count": current.daily_reading, "enabled": current.daily_reading > 0},
            {"task_type": "ai_minutes", "target_count": current.daily_listening_minutes, "enabled": current.daily_listening_minutes > 0},
            {"task_type": "writing", "target_count": writing_tasks, "enabled": writing_tasks > 0},
        ])

    # ===== 查询 =====

    async def get_dashboard(self, user_id: str) -> dict:
        today = date.today()
        r = await self.db.execute(select(CetGoal).where(CetGoal.user_id == user_id))
        goal = r.scalar_one_or_none()
        if not goal:
            return {"goal": None, "current_phase": None, "phases": [], "today_tasks": await PlanService(self.db).get_today_tasks(user_id), "progress": {"phase_done": 0, "total_phases": 4, "days_total": 0, "days_elapsed": 0}}

        r = await self.db.execute(
            select(CetStudyPlan).where(CetStudyPlan.user_id == user_id).order_by(CetStudyPlan.phase)
        )
        plans = r.scalars().all()
        phases = []
        current_phase = None
        phase_done = 0
        for p in plans:
            if p.end_date < today:
                status = "done"
                phase_done += 1
            elif p.start_date <= today <= p.end_date:
                status = "active"
                current_phase = p.phase
            else:
                status = "upcoming"
            phases.append({
                "phase": p.phase,
                "phase_name": p.phase_name,
                "focus": p.focus,
                "start_date": p.start_date.isoformat(),
                "end_date": p.end_date.isoformat(),
                "daily_words": p.daily_words,
                "daily_reading": p.daily_reading,
                "daily_listening_minutes": p.daily_listening_minutes,
                "daily_writing_minutes": p.daily_writing_minutes,
                "status": status,
            })
        days_total = (goal.exam_date - (plans[0].start_date if plans else today)).days if plans else 0
        days_elapsed = max(0, (today - (plans[0].start_date if plans else today)).days) if plans else 0
        return {
            "goal": {
                "exam_type": goal.exam_type,
                "target_score": goal.target_score,
                "exam_date": goal.exam_date.isoformat(),
                "daily_minutes": goal.daily_minutes,
                "days_left": (goal.exam_date - today).days,
            },
            "current_phase": current_phase,
            "phases": phases,
            "today_tasks": await PlanService(self.db).get_today_tasks(user_id),
            "progress": {
                "phase_done": phase_done,
                "total_phases": len(PHASE_TEMPLATE),
                "days_total": max(0, days_total),
                "days_elapsed": days_elapsed,
            },
        }

    async def _current_phase(self, user_id: str, day: date) -> Optional[CetStudyPlan]:
        r = await self.db.execute(
            select(CetStudyPlan).where(
                and_(
                    CetStudyPlan.user_id == user_id,
                    CetStudyPlan.start_date <= day,
                    CetStudyPlan.end_date >= day,
                )
            ).order_by(CetStudyPlan.phase)
        )
        return r.scalars().first()
