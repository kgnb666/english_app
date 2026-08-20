# services/reading_service.py - AI Reading Assistant with history

import json, re
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession
from app.ai.client import ai_client
from app.ai.prompts import READING_ANALYSIS_PROMPT
from app.models.history import ReadingRecord
from app.services.profile_service import ProfileService


class ReadingService:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def analyze(self, article: str, user_id: str) -> dict:
        user_context = await self._user_context(user_id)
        prompt = READING_ANALYSIS_PROMPT.format(
            article=article[:3000], user_context=user_context
        )
        try:
            reply = await ai_client.chat(messages=[{"role": "user", "content": prompt}], temperature=0.3, max_tokens=2000)
            result = self._parse_json(reply)
        except Exception:
            result = {"summary_cn": "AI analysis unavailable.", "vocabulary": [], "complex_sentences": [], "main_idea": ""}
        # Auto-save record
        rec = ReadingRecord(user_id=user_id, article_content=article[:3000], analysis_result=result)
        self.db.add(rec); await self.db.flush()
        # 真实学习行为：阅读次数 +1
        from app.services.stats_service import StatsService
        await StatsService(self.db).record_activity(user_id, "reading_count", 1)
        return result

    async def _user_context(self, user_id: str) -> str:
        ctx = await ProfileService(self.db).build_ai_context(user_id)
        skills = ctx.get("common_errors") or []
        skills_text = "none yet" if not skills else ", ".join(
            f"{e.get('type', '')}" for e in skills[:3]
        )
        prefs = ctx.get("preferences") or {}
        focus = (prefs.get("focus") or []) if isinstance(prefs, dict) else []
        focus_text = ", ".join(str(x) for x in focus) if focus else "general"
        return (
            f"level={ctx.get('level', 'beginner')}, "
            f"goal={ctx.get('goal', '')}, "
            f"weak skills={skills_text}, focus={focus_text}"
        )

    async def get_history(self, user_id: str, page: int = 1, page_size: int = 10) -> tuple[list[dict], int]:
        from sqlalchemy import func
        count_q = select(func.count()).select_from(select(ReadingRecord).where(ReadingRecord.user_id == user_id).subquery())
        total = (await self.db.execute(count_q)).scalar() or 0
        r = await self.db.execute(
            select(ReadingRecord).where(ReadingRecord.user_id == user_id)
            .order_by(desc(ReadingRecord.created_at))
            .offset((page-1)*page_size).limit(page_size)
        )
        rows = r.scalars().all()
        items = [{"id": x.id, "article_preview": x.article_content[:100],
            "summary_cn": (x.analysis_result or {}).get("summary_cn", ""),
            "created_at": x.created_at.isoformat()} for x in rows]
        return items, total

    async def get_record_detail(self, user_id: str, record_id: str) -> dict:
        r = await self.db.execute(select(ReadingRecord).where(
            ReadingRecord.id == record_id, ReadingRecord.user_id == user_id
        ))
        rec = r.scalar_one_or_none()
        if not rec:
            raise ValueError("Reading record not found")
        return {
            "id": rec.id,
            "article_content": rec.article_content,
            "analysis_result": rec.analysis_result,
            "created_at": rec.created_at.isoformat(),
        }

    async def delete_record(self, user_id: str, record_id: str) -> None:
        r = await self.db.execute(select(ReadingRecord).where(
            ReadingRecord.id == record_id, ReadingRecord.user_id == user_id
        ))
        rec = r.scalar_one_or_none()
        if not rec:
            raise ValueError("Reading record not found")
        await self.db.delete(rec)
        await self.db.flush()

    def _parse_json(self, text: str) -> dict:
        text = text.strip()
        if text.startswith("```"): text = text.split("```")[1]; text = text.strip()
        if text.startswith("json"): text = text[4:].strip()
        try: return json.loads(text)
        except json.JSONDecodeError: pass
        m = re.search(r"\{.*\}", text, re.DOTALL)
        if m:
            try: return json.loads(m.group())
            except json.JSONDecodeError: pass
        return {"summary_cn": "Could not parse AI response.", "vocabulary": [], "complex_sentences": [], "main_idea": ""}
