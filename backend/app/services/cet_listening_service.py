# services/cet_listening_service.py - 四六级听力训练（精听模式）

import asyncio
import json
import os
import re
from typing import Optional

import edge_tts
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cet_speech import CetListeningRecord
from app.models.vocabulary import VocabularyWord
from app.ai.client import ai_client
from app.ai.prompts import CET_LISTENING_ANALYSIS_PROMPT

_AUDIO_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "static", "audio", "cet_listening")
)
_audio_locks: dict[str, asyncio.Lock] = {}

# 内置听力材料（短文 + 题目）
LISTENING_ITEMS = [
    {
        "id": "cet4-l1",
        "exam_type": "CET4",
        "title": "A Visit to the Library",
        "script": (
            "Last weekend, I visited the city library for the first time. The building is very modern and bright. "
            "There is a large reading room on the second floor, and many students were studying there. "
            "I borrowed two books about history and one about science. The librarian was friendly and helped me find "
            "the books quickly. She also told me that the library opens at eight in the morning and closes at nine "
            "in the evening. I plan to go back next weekend to return the books and borrow some novels."
        ),
        "questions": [
            {"id": "q1", "question": "Where is the large reading room?", "options": ["On the first floor.", "On the second floor.", "On the third floor.", "In the basement."], "correct": 1},
            {"id": "q2", "question": "What books did the speaker borrow?", "options": ["Two novels and one science book.", "Two books about history and one about science.", "Three books about science.", "Two books about history and one novel."], "correct": 1},
            {"id": "q3", "question": "When does the library close?", "options": ["At six in the evening.", "At eight in the evening.", "At nine in the evening.", "At ten in the evening."], "correct": 2},
        ],
    },
    {
        "id": "cet4-l2",
        "exam_type": "CET4",
        "title": "Healthy Eating Habits",
        "script": (
            "Eating healthy does not mean giving up all your favorite foods. It means making smart choices every day. "
            "For example, you can replace fried snacks with fresh fruit, and drink water instead of sugary drinks. "
            "A balanced diet should include vegetables, fruit, grains, and protein. Doctors also suggest eating "
            "breakfast every morning, because it gives you energy for the whole day. Finally, remember that eating "
            "slowly helps your body digest food better and prevents overeating."
        ),
        "questions": [
            {"id": "q1", "question": "What does healthy eating mean according to the passage?", "options": ["Giving up all favorite foods.", "Making smart choices every day.", "Eating only vegetables.", "Never drinking water."], "correct": 1},
            {"id": "q2", "question": "What can replace fried snacks?", "options": ["Sugary drinks.", "More bread.", "Fresh fruit.", "Fast food."], "correct": 2},
            {"id": "q3", "question": "Why is breakfast important?", "options": ["It helps you sleep better.", "It gives you energy for the day.", "It makes food taste better.", "It helps you lose weight."], "correct": 1},
        ],
    },
    {
        "id": "cet6-l1",
        "exam_type": "CET6",
        "title": "The Future of Work",
        "script": (
            "The nature of work is changing faster than ever. Automation and artificial intelligence are replacing "
            "many routine tasks, forcing workers to develop new skills. Experts predict that within the next decade, "
            "almost half of all employees will need to be retrained. Lifelong learning is no longer a choice but a "
            "necessity. Universities and companies are working together to offer flexible courses that workers can "
            "take while keeping their jobs. The key message is clear: those who adapt quickly will thrive, while "
            "those who resist change may fall behind."
        ),
        "questions": [
            {"id": "q1", "question": "What is replacing many routine tasks?", "options": ["Human workers.", "Automation and artificial intelligence.", "Manual labor.", "Part-time employees."], "correct": 1},
            {"id": "q2", "question": "What do experts predict about employees?", "options": ["Most will retire early.", "Almost half will need retraining.", "All will work from home.", "Salaries will double."], "correct": 1},
            {"id": "q3", "question": "What is the key message of the passage?", "options": ["Change is dangerous.", "Workers should resist change.", "Those who adapt quickly will thrive.", "Education is unnecessary."], "correct": 2},
        ],
    },
    {
        "id": "cet6-l2",
        "exam_type": "CET6",
        "title": "Urban Green Spaces",
        "script": (
            "Green spaces in cities are more than just decoration. Parks and gardens improve air quality, reduce "
            "noise, and provide places for people to relax. Studies show that spending time in nature can lower "
            "stress and improve mental health. However, as cities grow, these spaces are often threatened by new "
            "construction. City planners now face a difficult balance between development and the need to preserve "
            "green areas. Many cities have responded by building rooftop gardens and planting trees along streets. "
            "Such efforts show that urban development and environmental protection can go hand in hand."
        ),
        "questions": [
            {"id": "q1", "question": "What is the main benefit of green spaces mentioned first?", "options": ["They reduce construction costs.", "They improve air quality and reduce noise.", "They attract tourists.", "They increase property prices."], "correct": 1},
            {"id": "q2", "question": "What do studies show about nature?", "options": ["It lowers stress and improves mental health.", "It increases stress.", "It has no effect on health.", "It only helps animals."], "correct": 0},
            {"id": "q3", "question": "How have some cities responded?", "options": ["By building more highways.", "By removing parks.", "By building rooftop gardens and planting street trees.", "By banning all construction."], "correct": 2},
        ],
    },
]


class CetListeningService:

    def __init__(self, db: AsyncSession):
        self.db = db

    def get_items(self, exam_type: str) -> list[dict]:
        return [
            {
                "id": a["id"],
                "exam_type": a["exam_type"],
                "title": a["title"],
                "question_count": len(a["questions"]),
            }
            for a in LISTENING_ITEMS
            if a["exam_type"] == exam_type
        ]

    async def get_item(self, item_id: str) -> dict:
        item = next((a for a in LISTENING_ITEMS if a["id"] == item_id), None)
        if not item:
            raise ValueError("Listening item not found")
        audio_url = await self._ensure_audio(item)
        return {
            "id": item["id"],
            "exam_type": item["exam_type"],
            "title": item["title"],
            "script": item["script"],
            "audio_url": audio_url,
            "questions": [
                {"id": q["id"], "question": q["question"], "options": q["options"]}
                for q in item["questions"]
            ],
        }

    async def submit(
        self, user_id: str, exam_type: str, item_id: str, answers: list[dict]
    ) -> dict:
        item = next((a for a in LISTENING_ITEMS if a["id"] == item_id), None)
        if not item:
            raise ValueError("Listening item not found")
        qmap = {q["id"]: q for q in item["questions"]}
        user_answers = {}
        results = []
        score = 0
        for ans in answers:
            qid = ans.get("question_id")
            choice = ans.get("answer")
            q = qmap.get(qid)
            if not q:
                continue
            ok = choice == q["correct"]
            if ok:
                score += 1
            user_answers[qid] = choice
            results.append({
                "question_id": qid,
                "correct_answer": q["correct"],
                "is_correct": ok,
            })
        total = len(item["questions"])
        audio_url = await self._ensure_audio(item)
        analysis = await self._analyze(item, results, user_answers)
        record = CetListeningRecord(
            user_id=user_id,
            exam_type=exam_type,
            item_id=item_id,
            title=item["title"],
            audio_url=audio_url,
            script=item["script"],
            questions=item["questions"],
            user_answers=user_answers,
            score=score,
            total=total,
            analysis=analysis,
        )
        self.db.add(record)
        await self.db.flush()
        await self.db.refresh(record)
        return {
            "id": record.id,
            "score": score,
            "total": total,
            "accuracy": round(score / total * 100) if total else 0,
            "analysis": analysis,
        }

    async def get_history(self, user_id: str, limit: int = 20) -> list[dict]:
        r = await self.db.execute(
            select(CetListeningRecord)
            .where(CetListeningRecord.user_id == user_id)
            .order_by(desc(CetListeningRecord.created_at))
            .limit(min(max(limit, 1), 100))
        )
        return [
            {
                "id": x.id,
                "exam_type": x.exam_type,
                "title": x.title,
                "score": x.score,
                "total": x.total,
                "accuracy": round(x.score / x.total * 100) if x.total else 0,
                "created_at": x.created_at.isoformat(),
            }
            for x in r.scalars().all()
        ]

    # ===== 音频生成（edge-tts） =====

    async def _ensure_audio(self, item: dict) -> str:
        lock = _audio_locks.setdefault(item["id"], asyncio.Lock())
        async with lock:
            rel = f"/static/audio/cet_listening/{item['id']}.mp3"
            path = os.path.join(_AUDIO_DIR, f"{item['id']}.mp3")
            if os.path.exists(path):
                return rel
            os.makedirs(_AUDIO_DIR, exist_ok=True)
            try:
                communicate = edge_tts.Communicate(item["script"], voice="en-US-AriaNeural")
                chunks = []
                async for chunk in communicate.stream():
                    if chunk["type"] == "audio":
                        chunks.append(chunk["data"])
                if chunks:
                    with open(path, "wb") as f:
                        f.write(b"".join(chunks))
                    return rel
            except Exception as e:
                print(f"Listening audio generation failed: {e}")
        return ""

    # ===== AI 逐句解析 =====

    async def _analyze(self, item: dict, results: list[dict], user_answers: dict) -> dict:
        questions_text = "\n".join(
            f"{q['id']}: {q['question']} | options: {' / '.join(q['options'])} | correct: {q['options'][q['correct']]}"
            for q in item["questions"]
        )
        answers_text = "; ".join(
            f"{r['question_id']} -> {user_answers.get(r['question_id'], '未作答')}"
            for r in results
        )
        prompt = CET_LISTENING_ANALYSIS_PROMPT.format(
            script=item["script"], questions=questions_text, user_answers=answers_text
        )
        try:
            reply = await ai_client.chat(
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=2000,
                json_mode=True,
            )
            parsed = self._parse_json(reply)
            if parsed:
                return {
                    "per_question": parsed.get("per_question") or [],
                    "sentence_analysis": parsed.get("sentence_analysis") or [],
                    "vocabulary": parsed.get("vocabulary") or [],
                }
        except Exception:
            pass
        return await self._fallback_analysis(item, results)

    async def _fallback_analysis(self, item: dict, results: list[dict]) -> dict:
        per_question = []
        for q in item["questions"]:
            wrong = any(r["question_id"] == q["id"] and not r["is_correct"] for r in results)
            per_question.append({
                "question_id": q["id"],
                "correct_reason": "根据听力内容中的关键信息可确定答案。",
                "trap": "干扰项常混淆相近信息。" if wrong else "本题作答正确",
            })
        sentences = re.split(r"(?<=[.!?])\s+", item["script"])
        vocab = []
        seen = set()
        for token in re.findall(r"[A-Za-z]{6,}", item["script"].lower()):
            if token in seen:
                continue
            seen.add(token)
            r = await self.db.execute(select(VocabularyWord).where(VocabularyWord.word == token))
            w = r.scalar_one_or_none()
            vocab.append({"word": token, "definition_cn": w.chinese_definition if w else ""})
            if len(vocab) >= 8:
                break
        return {
            "per_question": per_question,
            "sentence_analysis": [
                {"original": s, "translation_cn": ""} for s in sentences
            ],
            "vocabulary": vocab,
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
