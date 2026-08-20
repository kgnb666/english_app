# services/backup_service.py - 数据导出与恢复服务

import uuid
from datetime import date, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.chat import ChatSession, ChatMessage, MessageRole
from app.models.vocabulary import UserWordProgress, VocabularyWord, WordStatus
from app.models.history import ReadingRecord, WritingRecord
from app.models.stats import DailyStats


class BackupService:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def export_all(self, user_id: str) -> dict:
        """导出用户全部学习数据为 JSON"""
        data = {"user_id": user_id, "exported_at": __import__("datetime").datetime.utcnow().isoformat()}

        # 聊天记录
        sessions = (await self.db.execute(select(ChatSession).where(ChatSession.user_id == user_id))).scalars().all()
        chats = []
        for s in sessions:
            chats.append({
                "id": s.id, "title": s.title, "topic": s.topic, "created_at": s.created_at.isoformat(),
                "messages": await self._session_messages(s.id),
            })
        data["chat_history"] = chats

        # 单词进度
        rows = (await self.db.execute(select(UserWordProgress).where(UserWordProgress.user_id == user_id))).scalars().all()
        words = []
        for p in rows:
            w = (await self.db.execute(select(VocabularyWord).where(VocabularyWord.id == p.word_id))).scalar_one_or_none()
            words.append({
                "word": w.word if w else p.word_id, "status": p.status.value, "review_count": p.review_count,
                "next_review_date": p.next_review_date.isoformat() if p.next_review_date else None,
                "memory_aid": p.memory_aid,
            })
        data["word_progress"] = words

        # 阅读记录
        readings = (await self.db.execute(select(ReadingRecord).where(ReadingRecord.user_id == user_id))).scalars().all()
        data["reading_records"] = [{"article_content": r.article_content, "analysis_result": r.analysis_result, "created_at": r.created_at.isoformat()} for r in readings]

        # 作文记录
        writings = (await self.db.execute(select(WritingRecord).where(WritingRecord.user_id == user_id))).scalars().all()
        data["writing_records"] = [{"original_text": w.original_text, "score": w.score, "correction_result": w.correction_result, "created_at": w.created_at.isoformat()} for w in writings]

        # 每日统计
        stats = (await self.db.execute(select(DailyStats).where(DailyStats.user_id == user_id))).scalars().all()
        data["daily_stats"] = [{
            "date": s.date.isoformat(),
            "study_minutes": s.study_minutes,
            "study_seconds": s.study_seconds,
            "words_learned": s.words_learned,
            "words_reviewed": s.words_reviewed,
            "chat_messages": s.chat_messages,
            "ai_minutes": s.ai_minutes,
            "reading_count": s.reading_count,
            "writing_count": s.writing_count,
        } for s in stats]

        return data

    async def restore_all(self, user_id: str, data: dict) -> dict:
        """从导出的 JSON 恢复用户学习数据（幂等：已存在的记录跳过）"""
        result = {
            "chat_sessions": 0, "chat_messages": 0,
            "word_progress": 0, "reading_records": 0,
            "writing_records": 0, "daily_stats": 0, "skipped": 0,
        }
        data = data or {}

        # 1. 聊天记录
        for s in data.get("chat_history") or []:
            session_id = s.get("id") or str(uuid.uuid4())
            exists = (await self.db.execute(select(ChatSession).where(ChatSession.id == session_id))).scalar_one_or_none()
            if exists:
                result["skipped"] += 1
                continue
            session = ChatSession(
                id=session_id,
                user_id=user_id,
                title=s.get("title") or "恢复的对话",
                topic=s.get("topic"),
                created_at=self._parse_datetime(s.get("created_at")),
            )
            self.db.add(session)
            result["chat_sessions"] += 1
            for m in s.get("messages") or []:
                try:
                    role = MessageRole(m.get("role") or "user")
                except ValueError:
                    role = MessageRole.USER
                self.db.add(ChatMessage(
                    session_id=session_id,
                    role=role,
                    content=m.get("content") or "",
                    grammar_corrections=m.get("grammar_corrections"),
                    created_at=self._parse_datetime(m.get("created_at")),
                ))
                result["chat_messages"] += 1

        # 2. 单词进度（按单词文本关联词库，保留词库 ID 关联）
        for w in data.get("word_progress") or []:
            word_text = w.get("word")
            if not word_text:
                result["skipped"] += 1
                continue
            word = (await self.db.execute(select(VocabularyWord).where(VocabularyWord.word == word_text))).scalar_one_or_none()
            if not word:
                result["skipped"] += 1
                continue
            prog = (await self.db.execute(select(UserWordProgress).where(
                UserWordProgress.user_id == user_id, UserWordProgress.word_id == word.id
            ))).scalar_one_or_none()
            if not prog:
                prog = UserWordProgress(user_id=user_id, word_id=word.id)
                self.db.add(prog)
            try:
                prog.status = WordStatus(w.get("status") or "new")
            except ValueError:
                prog.status = WordStatus.NEW
            prog.review_count = int(w.get("review_count") or 0)
            prog.next_review_date = self._parse_date(w.get("next_review_date"))
            prog.memory_aid = w.get("memory_aid")
            result["word_progress"] += 1

        # 3. 阅读记录（按内容去重）
        for r in data.get("reading_records") or []:
            content = r.get("article_content") or ""
            created = self._parse_datetime(r.get("created_at"))
            dup = (await self.db.execute(select(ReadingRecord).where(
                ReadingRecord.user_id == user_id,
                ReadingRecord.article_content == content,
            ))).scalar_one_or_none()
            if dup:
                result["skipped"] += 1
                continue
            self.db.add(ReadingRecord(
                user_id=user_id,
                article_content=content,
                analysis_result=r.get("analysis_result"),
                created_at=created,
            ))
            result["reading_records"] += 1

        # 4. 作文记录（按内容去重）
        for w in data.get("writing_records") or []:
            text = w.get("original_text") or ""
            created = self._parse_datetime(w.get("created_at"))
            dup = (await self.db.execute(select(WritingRecord).where(
                WritingRecord.user_id == user_id,
                WritingRecord.original_text == text,
            ))).scalar_one_or_none()
            if dup:
                result["skipped"] += 1
                continue
            self.db.add(WritingRecord(
                user_id=user_id,
                original_text=text,
                score=w.get("score"),
                correction_result=w.get("correction_result"),
                created_at=created,
            ))
            result["writing_records"] += 1

        # 5. 每日统计（按日期 upsert）
        for s in data.get("daily_stats") or []:
            day = self._parse_date(s.get("date"))
            if not day:
                result["skipped"] += 1
                continue
            stats = (await self.db.execute(select(DailyStats).where(
                DailyStats.user_id == user_id, DailyStats.date == day
            ))).scalar_one_or_none()
            if not stats:
                stats = DailyStats(user_id=user_id, date=day)
                self.db.add(stats)
                result["daily_stats"] += 1
            else:
                result["skipped"] += 1
            stats.study_minutes = int(s.get("study_minutes") or 0)
            stats.study_seconds = int(s.get("study_seconds") or stats.study_minutes * 60)
            stats.words_learned = int(s.get("words_learned") or 0)
            stats.words_reviewed = int(s.get("words_reviewed") or 0)
            stats.chat_messages = int(s.get("chat_messages") or 0)
            stats.ai_minutes = int(s.get("ai_minutes") or 0)
            stats.reading_count = int(s.get("reading_count") or 0)
            stats.writing_count = int(s.get("writing_count") or 0)

        await self.db.flush()
        return result

    async def _session_messages(self, session_id: str) -> list[dict]:
        """读取会话消息；对历史脏数据（角色枚举值大小写异常）做容错"""
        try:
            msgs = (await self.db.execute(select(ChatMessage).where(ChatMessage.session_id == session_id))).scalars().all()
            return [
                {
                    "role": m.role.value,
                    "content": m.content,
                    "grammar_corrections": m.grammar_corrections,
                    "created_at": m.created_at.isoformat(),
                }
                for m in msgs
            ]
        except LookupError:
            from sqlalchemy import text
            rows = (await self.db.execute(
                text("SELECT role, content, grammar_corrections, created_at FROM chat_messages WHERE session_id = :sid"),
                {"sid": session_id},
            )).all()
            return [
                {
                    "role": r[0],
                    "content": r[1],
                    "grammar_corrections": r[2],
                    "created_at": r[3].isoformat() if hasattr(r[3], "isoformat") else str(r[3]),
                }
                for r in rows
            ]

    @staticmethod
    def _parse_datetime(value):
        if not value:
            return datetime.utcnow()
        try:
            return datetime.fromisoformat(str(value).replace("Z", "+00:00")).replace(tzinfo=None)
        except (ValueError, TypeError):
            return datetime.utcnow()

    @staticmethod
    def _parse_date(value):
        if not value:
            return None
        try:
            return date.fromisoformat(str(value)[:10])
        except (ValueError, TypeError):
            return None
