# services/cet_speaking_service.py - 四六级 AI 口语考试模拟

import json
import re
from typing import Optional

from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cet_speech import CetSpeakingRecord
from app.ai.client import ai_client
from app.ai.prompts import CET_SPEAKING_PROMPT

# 内置口语考试问题
SPEAKING_QUESTIONS = [
    {"id": "cet4-s1", "exam_type": "CET4", "question": "Please introduce yourself and talk about your hometown."},
    {"id": "cet4-s2", "exam_type": "CET4", "question": "What do you like to do in your free time? Why?"},
    {"id": "cet4-s3", "exam_type": "CET4", "question": "Talk about your favorite subject at school."},
    {"id": "cet6-s1", "exam_type": "CET6", "question": "What are the advantages and disadvantages of online learning?"},
    {"id": "cet6-s2", "exam_type": "CET6", "question": "Should college students take part-time jobs? Give your reasons."},
    {"id": "cet6-s3", "exam_type": "CET6", "question": "How can technology help protect the environment?"},
]


class CetSpeakingService:

    def __init__(self, db: AsyncSession):
        self.db = db

    def get_questions(self, exam_type: str) -> list[dict]:
        return [
            {"id": q["id"], "exam_type": q["exam_type"], "question": q["question"]}
            for q in SPEAKING_QUESTIONS
            if q["exam_type"] == exam_type
        ]

    async def submit(
        self,
        user_id: str,
        exam_type: str,
        question: str,
        user_answer: str,
    ) -> dict:
        """AI 口语评分：流利度 / 语法 / 词汇 / 发音"""
        if not user_answer.strip():
            raise ValueError("user_answer is required")
        analysis = await self._score_with_ai(question, user_answer)
        scores = analysis.get("scores") or {}
        score = analysis.get("score") or 0
        record = CetSpeakingRecord(
            user_id=user_id,
            exam_type=exam_type,
            question=question[:1000],
            user_answer=user_answer.strip()[:2000],
            score=score,
            scores=scores,
            analysis=analysis,
        )
        self.db.add(record)
        await self.db.flush()
        await self.db.refresh(record)
        return {
            "id": record.id,
            "score": score,
            "scores": scores,
            "analysis": analysis,
        }

    async def get_history(self, user_id: str, limit: int = 20) -> list[dict]:
        r = await self.db.execute(
            select(CetSpeakingRecord)
            .where(CetSpeakingRecord.user_id == user_id)
            .order_by(desc(CetSpeakingRecord.created_at))
            .limit(min(max(limit, 1), 100))
        )
        return [
            {
                "id": x.id,
                "exam_type": x.exam_type,
                "question": x.question,
                "user_answer": x.user_answer,
                "score": x.score,
                "created_at": x.created_at.isoformat(),
            }
            for x in r.scalars().all()
        ]

    async def _score_with_ai(self, question: str, answer: str) -> dict:
        prompt = CET_SPEAKING_PROMPT.format(question=question, answer=answer)
        try:
            reply = await ai_client.chat(
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=1500,
                json_mode=True,
            )
            parsed = self._parse_json(reply)
            if parsed:
                scores = parsed.get("scores") or {}
                score = max(0, min(20, int(parsed.get("score") or 0)))
                return {
                    "score": score,
                    "scores": scores,
                    "analysis": str(parsed.get("analysis") or ""),
                    "suggestions": [str(s) for s in parsed.get("suggestions") or []],
                }
        except Exception:
            pass
        return {
            "score": 0,
            "scores": {},
            "analysis": "",
            "suggestions": ["AI 评分暂时不可用，请稍后重试。"],
        }

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
