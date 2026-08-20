# services/cet_writing_service.py - 四六级作文训练 + 模板库

import json
import re
from typing import Optional

from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.history import WritingRecord
from app.models.cet_writing import WritingTemplate
from app.ai.client import ai_client
from app.ai.prompts import CET_ESSAY_REVIEW_PROMPT, WRITING_TEMPLATE_PROMPT


class CetWritingService:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def review_essay(self, user_id: str, essay: str, exam_type: str) -> dict:
        """四六级作文批改：15 分制 + 结构/词汇/语法/逻辑 + 修改版"""
        result = await self._analyze_with_ai(essay, exam_type)
        record = WritingRecord(
            user_id=user_id,
            exam_type=exam_type,
            original_text=essay[:3000],
            score=result.get("score", 0),
            correction_result=result,
        )
        self.db.add(record)
        await self.db.flush()
        return result

    async def _analyze_with_ai(self, essay: str, exam_type: str) -> dict:
        prompt = CET_ESSAY_REVIEW_PROMPT.format(exam_type=exam_type, essay=essay[:3000])
        try:
            reply = await ai_client.chat(
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=2000,
                json_mode=True,
            )
            parsed = self._parse_json(reply)
            if parsed:
                score = max(0, min(15, int(parsed.get("score") or 0)))
                return {
                    "score": score,
                    "scores": parsed.get("scores") or {},
                    "errors": parsed.get("errors") or [],
                    "suggestions": [str(s) for s in parsed.get("suggestions") or []],
                    "optimized": str(parsed.get("optimized") or ""),
                }
        except Exception:
            pass
        return {
            "score": 0,
            "scores": {},
            "errors": [],
            "suggestions": ["AI 批改暂时不可用，请稍后重试。"],
            "optimized": "",
        }

    # ===== 模板库 =====

    async def get_templates(self, user_id: str) -> list[dict]:
        r = await self.db.execute(
            select(WritingTemplate).where(WritingTemplate.user_id == user_id)
            .order_by(WritingTemplate.created_at.desc())
        )
        return [
            {
                "id": t.id,
                "title": t.title,
                "content": t.content,
                "category": t.category,
                "is_ai_recommended": t.is_ai_recommended,
                "created_at": t.created_at.isoformat(),
            }
            for t in r.scalars().all()
        ]

    async def create_template(
        self, user_id: str, title: str, content: str, category: Optional[str] = None
    ) -> dict:
        if not title.strip() or not content.strip():
            raise ValueError("title and content are required")
        t = WritingTemplate(
            user_id=user_id,
            title=title.strip()[:100],
            content=content.strip(),
            category=category,
        )
        self.db.add(t)
        await self.db.flush()
        await self.db.refresh(t)
        return {
            "id": t.id, "title": t.title, "content": t.content,
            "category": t.category, "is_ai_recommended": False,
        }

    async def delete_template(self, user_id: str, template_id: str) -> None:
        r = await self.db.execute(
            select(WritingTemplate).where(
                WritingTemplate.id == template_id, WritingTemplate.user_id == user_id
            )
        )
        t = r.scalar_one_or_none()
        if not t:
            raise ValueError("Template not found")
        await self.db.delete(t)
        await self.db.flush()

    async def ai_recommend_template(
        self, user_id: str, exam_type: str, category: str = "议论文"
    ) -> dict:
        """AI 生成推荐模板并保存"""
        prompt = WRITING_TEMPLATE_PROMPT.format(exam_type=exam_type, category=category)
        try:
            reply = await ai_client.chat(
                messages=[{"role": "user", "content": prompt}],
                temperature=0.5,
                max_tokens=1200,
                json_mode=True,
            )
            parsed = self._parse_json(reply)
            if parsed:
                t = WritingTemplate(
                    user_id=user_id,
                    title=str(parsed.get("title") or f"{exam_type} {category}模板")[:100],
                    content=str(parsed.get("content") or ""),
                    category=str(parsed.get("category") or category),
                    is_ai_recommended=True,
                )
                self.db.add(t)
                await self.db.flush()
                await self.db.refresh(t)
                return {
                    "id": t.id, "title": t.title, "content": t.content,
                    "category": t.category, "is_ai_recommended": True,
                }
        except Exception:
            pass
        raise ValueError("AI template generation failed")

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
