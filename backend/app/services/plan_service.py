# services/plan_service.py - 学习计划服务：模板 + 每日自动生成任务

from datetime import date

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.plan import LearningPlan, DailyTask
from app.models.stats import DailyStats
from app.models.user import User

# 支持的任务类型（顺序即展示顺序）
TASK_TYPES = ["words", "ai_minutes", "reading", "writing"]
TASK_TYPE_SET = set(TASK_TYPES)

# 没有配置计划时的默认目标
DEFAULT_PLAN = {
    "words": 30,
    "ai_minutes": 20,
    "reading": 1,
    "writing": 0,
}

# 任务类型 -> 真实统计字段映射
PROGRESS_FIELD = {
    "words": ("words_learned", "words_reviewed"),
    "ai_minutes": ("ai_minutes",),
    "reading": ("reading_count",),
    "writing": ("writing_count",),
}


class PlanService:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_plan(self, user_id: str) -> list[dict]:
        """获取用户学习计划模板（不存在则按默认值初始化）"""
        await self._ensure_templates(user_id)
        r = await self.db.execute(
            select(LearningPlan).where(LearningPlan.user_id == user_id)
        )
        rows = r.scalars().all()
        by_type = {x.task_type: x for x in rows}
        return [
            {
                "task_type": t,
                "target_count": by_type[t].target_count if t in by_type else DEFAULT_PLAN[t],
                "enabled": by_type[t].enabled if t in by_type else DEFAULT_PLAN[t] > 0,
            }
            for t in TASK_TYPES
        ]

    async def update_plan(self, user_id: str, items: list[dict]) -> list[dict]:
        """更新计划模板，并同步刷新今天的任务"""
        await self._ensure_templates(user_id)
        for item in items:
            task_type = str(item.get("task_type") or "")
            if task_type not in TASK_TYPE_SET:
                raise ValueError(f"Unsupported task type: {task_type}")
            target = max(0, int(item.get("target_count") or 0))
            enabled = bool(item.get("enabled", True))
            r = await self.db.execute(
                select(LearningPlan).where(
                    and_(
                        LearningPlan.user_id == user_id,
                        LearningPlan.task_type == task_type,
                    )
                )
            )
            plan = r.scalar_one_or_none()
            if not plan:
                plan = LearningPlan(user_id=user_id, task_type=task_type)
                self.db.add(plan)
            plan.target_count = target
            plan.enabled = enabled
        await self.db.flush()
        await self._ensure_today_tasks(user_id)
        return await self.get_plan(user_id)

    async def get_today_tasks(self, user_id: str) -> dict:
        """今日任务：按真实学习数据计算完成进度"""
        await self._ensure_templates(user_id)
        tasks = await self._ensure_today_tasks(user_id)

        today = date.today()
        r = await self.db.execute(
            select(DailyStats).where(
                and_(DailyStats.user_id == user_id, DailyStats.date == today)
            )
        )
        stats = r.scalar_one_or_none()

        result = []
        for task in sorted(tasks, key=lambda x: TASK_TYPES.index(x.task_type)):
            fields = PROGRESS_FIELD[task.task_type]
            completed = 0
            for f in fields:
                completed += getattr(stats, f) or 0 if stats else 0
            status = "completed" if task.target_count > 0 and completed >= task.target_count else "pending"
            # 回写真实进度，保持 daily_tasks 与统计一致
            task.completed_count = completed
            task.status = status
            result.append({
                "task_type": task.task_type,
                "target_count": task.target_count,
                "completed_count": completed,
                "status": status,
            })
        await self.db.flush()
        return {"date": today.isoformat(), "tasks": result}

    # ===== 内部工具 =====

    async def _ensure_templates(self, user_id: str) -> None:
        """确保用户有完整的学习计划模板（按默认值或用户每日目标初始化）"""
        r = await self.db.execute(
            select(LearningPlan).where(LearningPlan.user_id == user_id)
        )
        existing = {x.task_type for x in r.scalars().all()}
        missing = [t for t in TASK_TYPES if t not in existing]
        if not missing:
            return
        user = (await self.db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
        defaults = dict(DEFAULT_PLAN)
        if user:
            defaults["words"] = user.daily_goal_words or 30
            defaults["ai_minutes"] = user.daily_goal_minutes or 20
        for t in missing:
            self.db.add(LearningPlan(
                user_id=user_id,
                task_type=t,
                target_count=defaults[t],
                enabled=defaults[t] > 0,
            ))
        await self.db.flush()

    async def _ensure_today_tasks(self, user_id: str) -> list[DailyTask]:
        """按模板为今天生成任务（幂等 upsert，目标值跟随模板）"""
        today = date.today()
        r = await self.db.execute(
            select(LearningPlan).where(
                and_(LearningPlan.user_id == user_id, LearningPlan.enabled.is_(True))
            )
        )
        plans = r.scalars().all()
        r = await self.db.execute(
            select(DailyTask).where(
                and_(DailyTask.user_id == user_id, DailyTask.task_date == today)
            )
        )
        tasks = {x.task_type: x for x in r.scalars().all()}
        for plan in plans:
            task = tasks.get(plan.task_type)
            if not task:
                task = DailyTask(
                    user_id=user_id,
                    task_date=today,
                    task_type=plan.task_type,
                    target_count=plan.target_count,
                )
                self.db.add(task)
                tasks[plan.task_type] = task
            elif task.target_count != plan.target_count:
                task.target_count = plan.target_count
        await self.db.flush()
        return list(tasks.values())
