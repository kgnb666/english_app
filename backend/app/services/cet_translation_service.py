# services/cet_translation_service.py - 四六级翻译训练

import json
import re
from typing import Optional

from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cet_writing import CetTranslation
from app.ai.client import ai_client
from app.ai.prompts import CET_TRANSLATION_PROMPT

# 内置翻译句子（真题风格，含参考译文）
TRANSLATION_SENTENCES = [
    {"id": "cet4-tr-1", "exam_type": "CET4", "chinese": "越来越多的人选择在网上购物，因为既方便又便宜。", "reference": "More and more people choose to shop online because it is convenient and inexpensive."},
    {"id": "cet4-tr-2", "exam_type": "CET4", "chinese": "春节期间，人们会回家与家人团聚，共度美好时光。", "reference": "During the Spring Festival, people return home to reunite with their families and enjoy quality time together."},
    {"id": "cet4-tr-3", "exam_type": "CET4", "chinese": "随着科技的发展，智能手机已成为我们生活中不可缺少的一部分。", "reference": "With the development of technology, smartphones have become an indispensable part of our lives."},
    {"id": "cet6-tr-1", "exam_type": "CET6", "chinese": "在全球化背景下，跨文化沟通能力变得越来越重要。", "reference": "In the context of globalization, cross-cultural communication skills are becoming increasingly important."},
    {"id": "cet6-tr-2", "exam_type": "CET6", "chinese": "中国政府高度重视环境保护，出台了一系列措施减少污染。", "reference": "The Chinese government attaches great importance to environmental protection and has introduced a series of measures to reduce pollution."},
    {"id": "cet6-tr-3", "exam_type": "CET6", "chinese": "人工智能的迅速发展正在深刻改变人们的生活和工作方式。", "reference": "The rapid development of artificial intelligence is profoundly changing the way people live and work."},
]


class CetTranslationService:

    def __init__(self, db: AsyncSession):
        self.db = db

    def get_sentences(self, exam_type: str) -> list[dict]:
        """翻译句子列表（不含参考译文）"""
        return [
            {"id": s["id"], "exam_type": s["exam_type"], "chinese": s["chinese"]}
            for s in TRANSLATION_SENTENCES
            if s["exam_type"] == exam_type
        ]

    async def submit(
        self,
        user_id: str,
        exam_type: str,
        sentence_id: str,
        chinese_text: str,
        user_translation: str,
    ) -> dict:
        """AI 评分：词汇 / 语序 / 表达自然度 + 参考译文，保存记录"""
        sentence = next(
            (s for s in TRANSLATION_SENTENCES if s["id"] == sentence_id), None
        )
        chinese = chinese_text or (sentence["chinese"] if sentence else "")
        if not chinese or not user_translation.strip():
            raise ValueError("chinese_text and user_translation are required")

        analysis = await self._analyze_with_ai(chinese, user_translation)
        record = CetTranslation(
            user_id=user_id,
            exam_type=exam_type,
            chinese_text=chinese,
            user_translation=user_translation.strip(),
            score=analysis.get("score", 0),
            analysis=analysis,
        )
        self.db.add(record)
        await self.db.flush()
        await self.db.refresh(record)
        return {
            "id": record.id,
            "chinese_text": chinese,
            "user_translation": user_translation,
            "score": record.score,
            "analysis": analysis,
        }

    async def get_history(self, user_id: str, limit: int = 20) -> list[dict]:
        r = await self.db.execute(
            select(CetTranslation)
            .where(CetTranslation.user_id == user_id)
            .order_by(desc(CetTranslation.created_at))
            .limit(min(max(limit, 1), 100))
        )
        return [
            {
                "id": x.id,
                "exam_type": x.exam_type,
                "chinese_text": x.chinese_text,
                "user_translation": x.user_translation,
                "score": x.score,
                "created_at": x.created_at.isoformat(),
            }
            for x in r.scalars().all()
        ]

    async def _analyze_with_ai(self, chinese: str, translation: str) -> dict:
        prompt = CET_TRANSLATION_PROMPT.format(chinese=chinese, translation=translation)
        try:
            reply = await ai_client.chat(
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=1200,
                json_mode=True,
            )
            parsed = self._parse_json(reply)
            if parsed:
                score = max(0, min(10, int(parsed.get("score") or 0)))
                return {
                    "score": score,
                    "vocab_analysis": str(parsed.get("vocab_analysis") or ""),
                    "word_order_analysis": str(parsed.get("word_order_analysis") or ""),
                    "naturalness_analysis": str(parsed.get("naturalness_analysis") or ""),
                    "reference": str(parsed.get("reference") or ""),
                    "suggestions": [str(s) for s in parsed.get("suggestions") or []],
                }
        except Exception:
            pass
        return {
            "score": 0,
            "vocab_analysis": "",
            "word_order_analysis": "",
            "naturalness_analysis": "",
            "reference": "",
            "suggestions": ["AI 评分暂时不可用，请对照参考译文自查。"],
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
