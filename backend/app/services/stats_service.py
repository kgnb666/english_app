# services/stats_service.py - 学习统计服务

from datetime import date, datetime, timedelta
from typing import Optional

from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.stats import DailyStats
from app.models.study import StudySession
from app.models.user import User
from app.models.vocabulary import UserWordProgress, WordStatus

# 支持的四种学习类型
SESSION_TYPES = {"chat", "speaking", "words", "reading", "writing"}
# 单次会话时长上限（24 小时），防止异常上报
MAX_SESSION_SECONDS = 86400


class StatsService:

    def __init__(self, db: AsyncSession):
        self.db = db

    # ===== 学习计时 =====

    async def start_study_session(self, user_id: str, session_type: str) -> dict:
        """开始一次真实学习计时"""
        if session_type not in SESSION_TYPES:
            raise ValueError(f"Unsupported session type: {session_type}")
        session = StudySession(
            user_id=user_id,
            session_type=session_type,
            status="active",
            started_at=datetime.utcnow(),
        )
        self.db.add(session)
        await self.db.flush()
        await self.db.refresh(session)
        return {
            "session_id": session.id,
            "session_type": session.session_type,
            "started_at": session.started_at.isoformat(),
        }

    async def end_study_session(
        self, user_id: str, session_id: str, duration_seconds: int
    ) -> dict:
        """结束学习计时，按客户端上报的实际活跃秒数累计统计"""
        r = await self.db.execute(
            select(StudySession).where(
                StudySession.id == session_id, StudySession.user_id == user_id
            )
        )
        session = r.scalar_one_or_none()
        if not session:
            raise ValueError("Study session not found")
        if session.status != "active":
            raise ValueError("Study session already ended")

        # 客户端通过 Stopwatch 统计前台活跃秒数（后台自动暂停），
        # 服务端仅做上下限保护，不按墙钟二次裁减
        duration = min(max(0, int(duration_seconds)), MAX_SESSION_SECONDS)

        session.ended_at = datetime.utcnow()
        session.duration_seconds = duration
        session.status = "completed"
        await self.db.flush()

        minutes = duration // 60
        today = date.today()
        stats = await self._get_or_create_stats(user_id, today)
        stats.study_seconds += duration
        stats.study_minutes = stats.study_seconds // 60
        if session.session_type in ("chat", "speaking"):
            stats.ai_minutes += minutes
        await self._update_streak(user_id, today)
        await self.db.flush()
        await self.db.refresh(session)

        return {
            "session_id": session.id,
            "duration_seconds": duration,
            "minutes": minutes,
            "study_minutes": stats.study_minutes,
        }

    # ===== 行为记录 =====

    async def record_activity(
        self, user_id: str, activity_type: str, amount: int = 1
    ):
        """记录真实学习行为次数（时间统一由学习会话产生）"""
        today = date.today()
        stats = await self._get_or_create_stats(user_id, today)

        if activity_type == "chat":
            stats.chat_messages += amount
        elif activity_type == "words_learned":
            stats.words_learned += amount
        elif activity_type == "words_reviewed":
            stats.words_reviewed += amount
        elif activity_type == "reading_count":
            stats.reading_count += amount
        elif activity_type == "writing_count":
            stats.writing_count += amount
        elif activity_type == "study_minutes":
            # 兼容旧调用：按分钟同时累计秒数，保证秒/分钟一致
            stats.study_minutes += amount
            stats.study_seconds += amount * 60

        await self.db.flush()
        await self._update_streak(user_id, today)

    # ===== 仪表盘 =====

    async def get_dashboard(self, user_id: str) -> dict:
        """首页仪表盘数据"""
        today = date.today()
        today_stats = await self._get_stats_or_none(user_id, today)

        r = await self.db.execute(
            select(
                func.sum(DailyStats.study_minutes),
                func.sum(DailyStats.study_seconds),
                func.sum(DailyStats.words_learned),
                func.sum(DailyStats.words_reviewed),
                func.sum(DailyStats.chat_messages),
                func.sum(DailyStats.ai_minutes),
                func.sum(DailyStats.reading_count),
                func.sum(DailyStats.writing_count),
                func.count(DailyStats.id),
            ).where(DailyStats.user_id == user_id)
        )
        row = r.one()
        total_minutes = row[0] or 0
        total_seconds = row[1] or 0
        total_words = row[2] or 0
        total_reviewed = row[3] or 0
        total_msgs = row[4] or 0
        total_ai = row[5] or 0
        total_reading = row[6] or 0
        total_writing = row[7] or 0
        total_days = row[8] or 0

        r = await self.db.execute(
            select(func.count(UserWordProgress.id)).where(
                and_(
                    UserWordProgress.user_id == user_id,
                    UserWordProgress.status == WordStatus.MASTERED,
                )
            )
        )
        mastered = r.scalar() or 0

        r = await self.db.execute(
            select(func.count(UserWordProgress.id)).where(
                and_(
                    UserWordProgress.user_id == user_id,
                    UserWordProgress.status == WordStatus.REVIEW,
                    UserWordProgress.next_review_date <= today,
                )
            )
        )
        to_review = r.scalar() or 0

        r = await self.db.execute(select(User).where(User.id == user_id))
        user = r.scalar_one_or_none()
        streak = user.streak_days if user else 0

        return {
            "today": {
                "study_minutes": today_stats.study_minutes if today_stats else 0,
                "study_seconds": today_stats.study_seconds if today_stats else 0,
                "words_learned": today_stats.words_learned if today_stats else 0,
                "words_reviewed": today_stats.words_reviewed if today_stats else 0,
                "chat_messages": today_stats.chat_messages if today_stats else 0,
                "ai_minutes": today_stats.ai_minutes if today_stats else 0,
                "reading_count": today_stats.reading_count if today_stats else 0,
                "writing_count": today_stats.writing_count if today_stats else 0,
            },
            "total": {
                "study_minutes": total_minutes,
                "study_seconds": total_seconds,
                "words_learned": total_words,
                "words_reviewed": total_reviewed,
                "chat_messages": total_msgs,
                "ai_minutes": total_ai,
                "reading_count": total_reading,
                "writing_count": total_writing,
                "study_days": total_days,
            },
            "words": {
                "mastered": mastered,
                "to_review": to_review,
            },
            "streak_days": streak,
            "english_level": user.english_level.value if user else "beginner",
        }

    # ===== 周/月/日历统计 =====

    async def get_weekly_stats(self, user_id: str) -> list[dict]:
        """近 7 天每日统计"""
        today = date.today()
        start = today - timedelta(days=6)
        rows = await self._stats_between(user_id, start, today)
        result = []
        for d in range(7):
            day = start + timedelta(days=d)
            match = next((x for x in rows if x.date == day), None)
            result.append(self._stats_dict(day, match))
        return result

    async def get_monthly_stats(self, user_id: str, year: int, month: int) -> dict:
        """月度统计：当月汇总 + 每日明细"""
        start, end = self._month_range(year, month)
        rows = await self._stats_between(user_id, start, end)

        def _sum(field):
            return sum(getattr(x, field) or 0 for x in rows)

        totals = {
            "study_minutes": _sum("study_minutes"),
            "study_seconds": _sum("study_seconds"),
            "words_learned": _sum("words_learned"),
            "words_reviewed": _sum("words_reviewed"),
            "chat_messages": _sum("chat_messages"),
            "ai_minutes": _sum("ai_minutes"),
            "reading_count": _sum("reading_count"),
            "writing_count": _sum("writing_count"),
            "study_days": len(rows),
        }
        days = [self._stats_dict(day, next((x for x in rows if x.date == day), None))
                for day in self._each_day(start, end)]
        return {"year": year, "month": month, "total": totals, "days": days}

    async def get_calendar_stats(self, user_id: str, year: int, month: int) -> list[dict]:
        """学习日历：当月每天的学习情况"""
        start, end = self._month_range(year, month)
        rows = await self._stats_between(user_id, start, end)
        result = []
        for day in self._each_day(start, end):
            match = next((x for x in rows if x.date == day), None)
            result.append({
                "date": day.isoformat(),
                "study_minutes": match.study_minutes if match else 0,
                "studied": bool(match and match.study_minutes > 0),
            })
        return result

    # ===== 内部工具 =====

    async def _get_stats_or_none(self, user_id: str, day: date) -> Optional[DailyStats]:
        r = await self.db.execute(
            select(DailyStats).where(
                and_(DailyStats.user_id == user_id, DailyStats.date == day)
            )
        )
        return r.scalar_one_or_none()

    async def _get_or_create_stats(self, user_id: str, day: date) -> DailyStats:
        stats = await self._get_stats_or_none(user_id, day)
        if not stats:
            stats = DailyStats(
                user_id=user_id,
                date=day,
                study_minutes=0,
                study_seconds=0,
                words_learned=0,
                words_reviewed=0,
                chat_messages=0,
                ai_minutes=0,
                reading_count=0,
                writing_count=0,
            )
            self.db.add(stats)
            await self.db.flush()
        return stats

    async def _stats_between(self, user_id: str, start: date, end: date) -> list[DailyStats]:
        r = await self.db.execute(
            select(DailyStats).where(
                and_(
                    DailyStats.user_id == user_id,
                    DailyStats.date >= start,
                    DailyStats.date < end,
                )
            ).order_by(DailyStats.date)
        )
        return list(r.scalars().all())

    @staticmethod
    def _stats_dict(day: date, stats: Optional[DailyStats]) -> dict:
        return {
            "date": day.isoformat(),
            "study_minutes": stats.study_minutes if stats else 0,
            "study_seconds": stats.study_seconds if stats else 0,
            "words_learned": stats.words_learned if stats else 0,
            "words_reviewed": stats.words_reviewed if stats else 0,
            "chat_messages": stats.chat_messages if stats else 0,
            "ai_minutes": stats.ai_minutes if stats else 0,
            "reading_count": stats.reading_count if stats else 0,
            "writing_count": stats.writing_count if stats else 0,
        }

    @staticmethod
    def _month_range(year: int, month: int) -> tuple[date, date]:
        start = date(year, month, 1)
        end = date(year + 1, 1, 1) if month == 12 else date(year, month + 1, 1)
        return start, end

    @staticmethod
    def _each_day(start: date, end: date):
        day = start
        while day < end:
            yield day
            day += timedelta(days=1)

    async def _update_streak(self, user_id: str, today: date):
        r = await self.db.execute(select(User).where(User.id == user_id))
        user = r.scalar_one_or_none()
        if not user:
            return
        if user.last_study_date is None:
            user.streak_days = 1
        elif user.last_study_date == today:
            return  # 今天已更新
        elif user.last_study_date == today - timedelta(days=1):
            user.streak_days += 1
        else:
            user.streak_days = 1
        user.last_study_date = today
        await self.db.flush()
