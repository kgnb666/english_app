# services/pronunciation_service.py - 发音评测服务

import difflib
import json
import re
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.pronunciation import PronunciationRecord
from app.ai.client import ai_client


PRONUNCIATION_PROMPT = """You are an English pronunciation coach. Compare the target sentence with the user's speech recognition result, and analyze the pronunciation problems.

Target: {target}
Recognized: {recognized}
Likely wrong words: {diff_words}

Return ONLY valid JSON (no markdown):
{{
  "mispronounced_words": [
    {{
      "word": "the target word",
      "recognized": "what the user said (or empty)",
      "syllables": "syllable breakdown with stress, e.g. YES-ter-day",
      "tip": "short Chinese pronunciation tip"
    }}
  ],
  "suggestions": ["Chinese suggestion 1", "Chinese suggestion 2"],
  "overall_advice": "one-sentence Chinese overall advice"
}}

Rules:
- "mispronounced_words" should be empty array [] if there are no wrong words
- Only include words that actually differ or are likely mispronounced
- Keep suggestions concise (2-3 items)
"""


class PronunciationService:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def evaluate(
        self,
        user_id: str,
        target_text: str,
        recognized_text: str,
        confidence: Optional[float] = None,
    ) -> dict:
        """发音评测：识别文本对比 + AI 建议 + 落库"""
        target = (target_text or "").strip()
        recognized = (recognized_text or "").strip()
        if not target:
            raise ValueError("target_text is required")

        diff_words, score = self._score(target, recognized, confidence)
        result = await self._analyze_with_ai(target, recognized, diff_words, score)

        record = PronunciationRecord(
            user_id=user_id,
            target_text=target,
            recognized_text=recognized,
            score=score,
            result=result,
        )
        self.db.add(record)
        await self.db.flush()
        await self.db.refresh(record)

        # 发音也是真实学习行为：计入 AI 学习时间由前端学习计时负责
        return {
            "id": record.id,
            "score": score,
            "target_text": target,
            "recognized_text": recognized,
            "result": result,
            "created_at": record.created_at.isoformat(),
        }

    async def get_history(self, user_id: str, limit: int = 20) -> list[dict]:
        r = await self.db.execute(
            select(PronunciationRecord)
            .where(PronunciationRecord.user_id == user_id)
            .order_by(PronunciationRecord.created_at.desc())
            .limit(min(max(limit, 1), 100))
        )
        return [
            {
                "id": x.id,
                "target_text": x.target_text,
                "recognized_text": x.recognized_text,
                "score": x.score,
                "result": x.result or {},
                "created_at": x.created_at.isoformat(),
            }
            for x in r.scalars().all()
        ]

    # ===== 评分与差异分析 =====

    @staticmethod
    def _score(
        target: str,
        recognized: str,
        confidence: Optional[float],
    ) -> tuple[list[str], int]:
        """词级匹配评分（0-100），confidence 加权"""
        target_words = target.lower().split()
        rec_words = recognized.lower().split()
        diff_words = []
        if target_words and rec_words:
            matcher = difflib.SequenceMatcher(None, target_words, rec_words)
            for tag, i1, i2, j1, j2 in matcher.get_opcodes():
                if tag in ("replace", "delete"):
                    diff_words.extend(target_words[i1:i2])
        matched = sum(
            block.size
            for block in difflib.SequenceMatcher(None, target_words, rec_words).get_matching_blocks()
        )
        denom = max(len(target_words), len(rec_words), 1)
        word_acc = matched / denom
        if confidence is not None and 0 <= confidence <= 1:
            score = round(0.7 * word_acc * 100 + 0.3 * confidence * 100)
        else:
            score = round(word_acc * 100)
        return diff_words, min(100, max(0, score))

    async def _analyze_with_ai(
        self,
        target: str,
        recognized: str,
        diff_words: list[str],
        score: int,
    ) -> dict:
        """AI 生成错误音节与建议；失败时回退启发式结果"""
        diff_text = ", ".join(diff_words) if diff_words else "none"
        prompt = PRONUNCIATION_PROMPT.format(
            target=target, recognized=recognized or "(silence)", diff_words=diff_text
        )
        try:
            reply = await ai_client.chat(
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=800,
                json_mode=True,
            )
            parsed = self._parse_json(reply)
            if parsed:
                return {
                    "mispronounced_words": [
                        {
                            "word": str(w.get("word") or ""),
                            "recognized": str(w.get("recognized") or ""),
                            "syllables": str(w.get("syllables") or ""),
                            "tip": str(w.get("tip") or ""),
                        }
                        for w in parsed.get("mispronounced_words") or []
                        if isinstance(w, dict)
                    ],
                    "suggestions": [str(s) for s in parsed.get("suggestions") or []],
                    "overall_advice": str(parsed.get("overall_advice") or ""),
                }
        except Exception:
            pass
        return self._fallback_result(diff_words, score)

    @staticmethod
    def _fallback_result(diff_words: list[str], score: int) -> dict:
        if not diff_words:
            return {
                "mispronounced_words": [],
                "suggestions": ["发音很标准，继续保持！"],
                "overall_advice": "整体发音清晰，注意连读与语调的自然度。",
            }
        if score >= 80:
            advice = "整体不错，少数单词需要再纠正一下。"
        elif score >= 60:
            advice = "基本能听懂，重点练习标出的单词发音。"
        else:
            advice = "建议放慢语速，先逐词跟读再连成句子。"
        return {
            "mispronounced_words": [
                {
                    "word": w,
                    "recognized": "",
                    "syllables": "",
                    "tip": "请对照标准发音重读，注意元音与重音",
                }
                for w in diff_words
            ],
            "suggestions": [
                "对照标准发音逐词跟读",
                "放慢语速，注意每个音节清晰",
            ],
            "overall_advice": advice,
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
