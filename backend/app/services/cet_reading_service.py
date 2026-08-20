# services/cet_reading_service.py - 四六级阅读专项训练

import json
import re
from typing import Optional

from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cet_reading import CetReadingRecord
from app.models.vocabulary import VocabularyWord
from app.ai.client import ai_client
from app.ai.prompts import CET_READING_ANALYSIS_PROMPT

# 内置四六级阅读文章与题目（真题风格）
ARTICLES = [
    {
        "id": "cet4-ai-life",
        "exam_type": "CET4",
        "title": "Artificial Intelligence in Daily Life",
        "article": (
            "Artificial intelligence (AI) is becoming a part of our daily life in ways we may not notice. "
            "When you search for information online, AI helps sort the results. When you unlock your phone with your face, "
            "AI recognizes your image. Even the recommendation system that suggests videos or music is powered by AI. "
            "However, experts warn that we should use these tools carefully. While AI can save time and improve efficiency, "
            "it also raises questions about privacy. For example, the data we share online may be collected and used "
            "without our full understanding. As students, we need to learn not only how to use AI but also how to think "
            "about its effects on our lives."
        ),
        "questions": [
            {
                "id": "q1",
                "question": "What is the main idea of the passage?",
                "options": [
                    "AI is widely used in daily life and we should use it carefully.",
                    "AI is only used for unlocking phones.",
                    "AI has no effect on students.",
                    "AI should be banned in education.",
                ],
                "correct": 0,
            },
            {
                "id": "q2",
                "question": 'According to the passage, what does the phrase "powered by AI" mean?',
                "options": [
                    "The system is controlled by electricity.",
                    "The system works with the help of AI technology.",
                    "The system is broken down.",
                    "The system is powered by human labor.",
                ],
                "correct": 1,
            },
            {
                "id": "q3",
                "question": "What concern does the passage raise about AI?",
                "options": [
                    "AI is too expensive to use.",
                    "AI may collect personal data without users fully understanding.",
                    "AI cannot improve efficiency.",
                    "AI makes phones harder to unlock.",
                ],
                "correct": 1,
            },
        ],
    },
    {
        "id": "cet4-sleep",
        "exam_type": "CET4",
        "title": "Sleep and Memory",
        "article": (
            "Getting enough sleep is essential for learning. Scientists have found that sleep helps the brain "
            "turn short-term memories into long-term ones. When we study during the day and sleep at night, "
            "the information we learned is processed and stored more firmly. In one experiment, students who "
            "reviewed their notes before going to bed remembered the material better than those who stayed up late. "
            "Lack of sleep, on the other hand, reduces attention and makes it harder to focus in class. "
            "Experts suggest that college students should get seven to eight hours of sleep every night. "
            "A regular sleep schedule, avoiding screens before bed, and keeping the bedroom dark are simple "
            "ways to improve sleep quality."
        ),
        "questions": [
            {
                "id": "q1",
                "question": "What is the passage mainly about?",
                "options": [
                    "How to take notes in class.",
                    "The relationship between sleep and memory.",
                    "The importance of doing experiments.",
                    "How to use screens before bed.",
                ],
                "correct": 1,
            },
            {
                "id": "q2",
                "question": "According to the passage, which students remembered the material better?",
                "options": [
                    "Those who stayed up late studying.",
                    "Those who reviewed notes before sleeping.",
                    "Those who slept less than six hours.",
                    "Those who used phones before bed.",
                ],
                "correct": 1,
            },
            {
                "id": "q3",
                "question": "Which of the following is NOT suggested for better sleep?",
                "options": [
                    "Keeping a regular sleep schedule.",
                    "Avoiding screens before bed.",
                    "Staying up late to review notes.",
                    "Keeping the bedroom dark.",
                ],
                "correct": 2,
            },
        ],
    },
    {
        "id": "cet6-remote",
        "exam_type": "CET6",
        "title": "The Rise of Remote Work",
        "article": (
            "Remote work has transformed the modern workplace. Once considered a rare benefit, working from home "
            "is now a standard option for millions of employees. Supporters argue that remote work increases "
            "productivity, reduces commuting time, and offers greater flexibility. However, critics point out "
            "that it can blur the boundary between work and personal life, leading to longer hours and burnout. "
            "Companies are therefore adopting hybrid models, allowing employees to work both at home and in the office. "
            "The key to success, experts say, lies in clear communication and trust between managers and teams. "
            "As technology continues to improve, the debate over where and how we work is unlikely to disappear."
        ),
        "questions": [
            {
                "id": "q1",
                "question": "What is the author's attitude towards remote work?",
                "options": [
                    "Completely supportive.",
                    "Completely opposed.",
                    "Balanced, presenting both advantages and disadvantages.",
                    "Indifferent.",
                ],
                "correct": 2,
            },
            {
                "id": "q2",
                "question": 'What does the word "blur" in the passage most probably mean?',
                "options": [
                    "To make something clearer.",
                    "To make the difference less clear.",
                    "To remove something completely.",
                    "To improve something.",
                ],
                "correct": 1,
            },
            {
                "id": "q3",
                "question": "According to the passage, what is the key to successful remote work?",
                "options": [
                    "Longer working hours.",
                    "Fewer meetings.",
                    "Clear communication and trust.",
                    "Working only from the office.",
                ],
                "correct": 2,
            },
        ],
    },
    {
        "id": "cet6-green",
        "exam_type": "CET6",
        "title": "Green Energy Transition",
        "article": (
            "The transition to green energy is one of the most urgent challenges of our time. Fossil fuels "
            "such as coal and oil have powered economies for over a century, but their environmental cost is "
            "now impossible to ignore. Renewable sources like solar and wind power offer a cleaner alternative, "
            "yet they also bring new problems, including high initial costs and unstable supply. "
            "Energy storage technology is therefore becoming increasingly important. Improved batteries allow "
            "excess energy produced on sunny or windy days to be saved for later use. Governments around the world "
            "are investing heavily in this field, recognizing that a successful energy transition depends not only "
            "on producing clean power but also on storing it efficiently."
        ),
        "questions": [
            {
                "id": "q1",
                "question": "What is the passage mainly about?",
                "options": [
                    "The history of fossil fuels.",
                    "The challenges and solutions in the green energy transition.",
                    "The cost of solar panels.",
                    "The future of coal mining.",
                ],
                "correct": 1,
            },
            {
                "id": "q2",
                "question": "Why is energy storage technology becoming important?",
                "options": [
                    "Because renewable energy supply can be unstable.",
                    "Because batteries are cheap to produce.",
                    "Because governments want to ban solar power.",
                    "Because fossil fuels are running out completely.",
                ],
                "correct": 0,
            },
            {
                "id": "q3",
                "question": "What does the passage imply about a successful energy transition?",
                "options": [
                    "It only requires producing clean power.",
                    "It is impossible without government investment.",
                    "It requires both producing and storing clean energy efficiently.",
                    "It will happen naturally without any effort.",
                ],
                "correct": 2,
            },
        ],
    },
]


class CetReadingService:

    def __init__(self, db: AsyncSession):
        self.db = db

    def get_articles(self, exam_type: str) -> list[dict]:
        """文章列表（不含题目答案）"""
        return [
            {
                "id": a["id"],
                "exam_type": a["exam_type"],
                "title": a["title"],
                "question_count": len(a["questions"]),
            }
            for a in ARTICLES
            if a["exam_type"] == exam_type
        ]

    def get_article(self, article_id: str) -> dict:
        """文章详情 + 题目（不含正确答案，防作弊）"""
        article = next((a for a in ARTICLES if a["id"] == article_id), None)
        if not article:
            raise ValueError("Article not found")
        return {
            "id": article["id"],
            "exam_type": article["exam_type"],
            "title": article["title"],
            "article": article["article"],
            "questions": [
                {
                    "id": q["id"],
                    "question": q["question"],
                    "options": q["options"],
                }
                for q in article["questions"]
            ],
        }

    async def submit(
        self,
        user_id: str,
        exam_type: str,
        article_id: str,
        answers: list[dict],
    ) -> dict:
        """判分 + AI 分析 + 保存记录"""
        article = next((a for a in ARTICLES if a["id"] == article_id), None)
        if not article:
            raise ValueError("Article not found")

        question_map = {q["id"]: q for q in article["questions"]}
        user_answers = {}
        score = 0
        results = []
        for ans in answers:
            qid = ans.get("question_id")
            choice = ans.get("answer")
            q = question_map.get(qid)
            if not q:
                continue
            is_correct = choice == q["correct"]
            if is_correct:
                score += 1
            user_answers[qid] = choice
            results.append({
                "question_id": qid,
                "correct_answer": q["correct"],
                "is_correct": is_correct,
            })
        total = len(article["questions"])

        analysis = await self._analyze(article, results, user_answers)

        record = CetReadingRecord(
            user_id=user_id,
            exam_type=exam_type,
            article_id=article_id,
            title=article["title"],
            article=article["article"],
            questions=article["questions"],
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
            "results": results,
            "analysis": analysis,
        }

    async def get_history(self, user_id: str, limit: int = 20) -> list[dict]:
        r = await self.db.execute(
            select(CetReadingRecord)
            .where(CetReadingRecord.user_id == user_id)
            .order_by(desc(CetReadingRecord.created_at))
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

    async def get_record_detail(self, user_id: str, record_id: str) -> dict:
        r = await self.db.execute(
            select(CetReadingRecord).where(
                CetReadingRecord.id == record_id, CetReadingRecord.user_id == user_id
            )
        )
        rec = r.scalar_one_or_none()
        if not rec:
            raise ValueError("Record not found")
        return {
            "id": rec.id,
            "exam_type": rec.exam_type,
            "title": rec.title,
            "article": rec.article,
            "questions": rec.questions or [],
            "user_answers": rec.user_answers or {},
            "score": rec.score,
            "total": rec.total,
            "analysis": rec.analysis or {},
            "created_at": rec.created_at.isoformat(),
        }

    # ===== AI 分析 =====

    async def _analyze(self, article: dict, results: list[dict], user_answers: dict) -> dict:
        questions_text = "\n".join(
            f"{q['id']}: {q['question']} | options: {' / '.join(q['options'])} | correct: {q['options'][q['correct']]}"
            for q in article["questions"]
        )
        # 把系统判定的结果（选项文本 + 对错）传给 AI，AI 只负责原因分析，不参与判分
        question_map = {q["id"]: q for q in article["questions"]}
        judgment_lines = []
        for r in results:
            q = question_map.get(r["question_id"])
            if not q:
                continue
            choice = user_answers.get(r["question_id"])
            user_text = (
                q["options"][choice] if isinstance(choice, int) and 0 <= choice < len(q["options"])
                else "未作答"
            )
            judgment_lines.append(
                f"{r['question_id']}: 用户选择「{user_text}」| 正确答案「{q['options'][q['correct']]}」| 判定 {'正确' if r['is_correct'] else '错误'}"
            )
        answers_text = "\n".join(judgment_lines)
        prompt = CET_READING_ANALYSIS_PROMPT.format(
            article=article["article"],
            questions=questions_text,
            user_answers=answers_text,
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
                per_question = self._align_per_question(
                    parsed.get("per_question") or [], article, results
                )
                return {
                    "per_question": per_question,
                    "complex_sentences": parsed.get("complex_sentences") or [],
                    "vocabulary": parsed.get("vocabulary") or [],
                }
        except Exception:
            pass
        return await self._fallback_analysis(article, results)

    @staticmethod
    def _align_per_question(
        ai_items: list, article: dict, results: list[dict]
    ) -> list[dict]:
        """强制以系统判定为准：正确题 trap 固定为"本题作答正确"，错误题补陷阱说明。
        AI 只负责 correct_reason，对错判断不采用 AI 结果。"""
        by_id = {p.get("question_id"): p for p in ai_items if isinstance(p, dict)}
        corrected = []
        for r in results:
            item = dict(by_id.get(r["question_id"], {}))
            if r["is_correct"]:
                item["trap"] = "本题作答正确"
            else:
                trap = str(item.get("trap") or "").strip()
                if trap in ("", "本题作答正确"):
                    item["trap"] = "干扰项常通过偷换概念或以偏概全设置陷阱，建议对比原文细节定位答案。"
            corrected.append({
                "question_id": r["question_id"],
                "correct_reason": str(item.get("correct_reason") or "正确答案符合原文表述，其他选项在原文中缺少依据。"),
                "trap": str(item.get("trap") or ""),
            })
        return corrected

    async def _fallback_analysis(self, article: dict, results: list[dict]) -> dict:
        """AI 不可用时的基础分析"""
        wrong = [r for r in results if not r["is_correct"]]
        per_question = []
        for q in article["questions"]:
            is_wrong = any(r["question_id"] == q["id"] and not r["is_correct"] for r in results)
            per_question.append({
                "question_id": q["id"],
                "correct_reason": "正确答案符合原文表述，其他选项在原文中缺少依据。",
                "trap": "干扰项常通过偷换概念或以偏概全设置陷阱。" if is_wrong else "本题作答正确。",
            })
        # 长难句：按长度取前 3 句
        sentences = re.split(r"(?<=[.!?])\s+", article["article"])
        long_sentences = sorted(sentences, key=len, reverse=True)[:3]
        # 生词：查词库
        words = []
        seen = set()
        for token in re.findall(r"[A-Za-z]{6,}", article["article"].lower()):
            if token in seen or token in {"artificial", "intelligence", "according", "because", "however", "important", "students", "working"}:
                continue
            seen.add(token)
            r = await self.db.execute(
                select(VocabularyWord).where(VocabularyWord.word == token)
            )
            w = r.scalar_one_or_none()
            words.append({"word": token, "definition_cn": w.chinese_definition if w else ""})
            if len(words) >= 8:
                break
        return {
            "per_question": per_question,
            "complex_sentences": [
                {"original": s, "analysis_cn": "该句结构较长，建议先找主干再理解修饰成分。"}
                for s in long_sentences
            ],
            "vocabulary": words,
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
