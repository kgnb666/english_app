# services/vocabulary_service.py - 单词服务 + 测试系统

import asyncio
import json
import os
import random
import re
from datetime import date, timedelta
from typing import Optional

import edge_tts
from sqlalchemy import select, func, or_, and_, case
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.vocabulary import (
    VocabularyWord,
    UserWordProgress,
    WordBook,
    WordExample,
    WordStatus,
)
from app.models.test import TestRecord
from app.ai.client import ai_client
from app.ai.prompts import MEMORY_AID_PROMPT
from app.schemas.vocabulary import VocabularyWordResponse, UserWordProgressResponse

# SM-2 参数
SM2_INITIAL_EF = 2.5
SM2_MIN_EF = 1.3
SM2_MASTER_REPETITION = 5  # 连续答对 5 次视为掌握

# 词库固定音频：backend/static/audio/words/<word>.mp3
_STATIC_AUDIO_DIR = os.path.normpath(
    os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "..", "static", "audio", "words"
    )
)
_AUDIO_VOICE = "en-US-AriaNeural"
_word_audio_locks: dict[str, asyncio.Lock] = {}

WORD_LEVEL_CN = {
    "core": "核心词",
    "high_freq": "高频词",
    "rare_meaning": "熟词僻义",
    "error_prone": "易错词",
}

# 内置真题风格例句：(单词, 例句, 中文翻译, 来源)
BUILTIN_EXAMPLES = [
    ("abandon", "The crew had to abandon the sinking ship in a hurry.", "船员们不得不匆忙弃船逃生。", "CET4-2023-12"),
    ("ability", "The ability to adapt quickly is essential in modern work.", "快速适应能力在现代工作中至关重要。", "CET4-2023-06"),
    ("abroad", "Many students choose to study abroad to broaden their horizons.", "许多学生选择出国留学以开阔视野。", "CET4-2022-12"),
    ("absence", "His absence from the meeting was not explained at all.", "他没有参加会议，而且没有任何解释。", "CET4-2022-06"),
    ("absolute", "She has absolute trust in the doctor's professional judgment.", "她完全信任医生的专业判断。", "CET6-2023-12"),
    ("absorb", "Plants absorb carbon dioxide from the atmosphere.", "植物从大气中吸收二氧化碳。", "CET6-2023-06"),
    ("abstract", "The report is too abstract for the general public to understand.", "这份报告过于抽象，普通公众难以理解。", "CET6-2022-12"),
    ("abundant", "The region is abundant in natural resources and wildlife.", "该地区自然资源和野生动植物十分丰富。", "CET6-2022-06"),
    ("academic", "His academic performance improved greatly after the tutoring.", "接受辅导后，他的学业成绩大幅提高。", "CET4-2021-12"),
    ("accelerate", "The government took measures to accelerate economic growth.", "政府采取措施加快经济增长。", "CET6-2021-06"),
]

# 词库分类 -> 默认难度
CATEGORY_DEFAULT_DIFFICULTY = {
    "CET4": "medium",
    "CET6": "medium",
    "KAOYAN": "medium",
    "IELTS": "hard",
    "TOEFL": "hard",
}

DIFFICULTY_ALIASES = {
    "easy": "easy",
    "medium": "medium",
    "hard": "hard",
    "EASY": "easy",
    "MEDIUM": "medium",
    "HARD": "hard",
    "简单": "easy",
    "中等": "medium",
    "困难": "hard",
    "难": "hard",
    "1": "easy",
    "2": "medium",
    "3": "hard",
    "4": "hard",
    "5": "hard",
}


class VocabularyService:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_words(
        self,
        user_id: str,
        status: Optional[str] = None,
        category: Optional[str] = None,
        search: Optional[str] = None,
        page: int = 1,
        page_size: int = 20,
        exam_type: Optional[str] = None,
        word_level: Optional[str] = None,
    ) -> tuple[list[dict], int]:
        query = select(VocabularyWord)
        if category: query = query.where(VocabularyWord.category == category)
        if exam_type: query = query.where(VocabularyWord.exam_type == exam_type)
        if word_level: query = query.where(VocabularyWord.word_level == word_level)
        q = (search or "").strip()
        if q:
            # autoescape=True 转义 % _ 通配符，避免搜索 % 匹配全部
            query = query.where(or_(
                VocabularyWord.word.contains(q, autoescape=True),
                VocabularyWord.chinese_definition.contains(q, autoescape=True),
            ))
        if status: query = query.join(UserWordProgress, UserWordProgress.word_id == VocabularyWord.id, isouter=True).where(UserWordProgress.user_id == user_id, UserWordProgress.status == status)
        # 相关性排序：前缀匹配优先，再按单词字母序
        if q:
            query = query.order_by(
                case((VocabularyWord.word.like(f"{q}%"), 0), else_=1),
                VocabularyWord.word.asc(),
            )
        else:
            query = query.order_by(VocabularyWord.word.asc())
        count_q = select(func.count()).select_from(query.subquery()); total = (await self.db.execute(count_q)).scalar() or 0
        offset = (page - 1) * page_size; rows = (await self.db.execute(query.offset(offset).limit(page_size))).scalars().all()
        # 批量查进度，消除 N+1
        word_ids = [w.id for w in rows]
        progress_map = {}
        if word_ids:
            pr = await self.db.execute(
                select(UserWordProgress).where(
                    and_(UserWordProgress.user_id == user_id, UserWordProgress.word_id.in_(word_ids))
                )
            )
            progress_map = {p.word_id: p for p in pr.scalars().all()}
        result = []
        for w in rows:
            prog = progress_map.get(w.id)
            d = VocabularyWordResponse.model_validate(w).model_dump()
            d["progress"] = UserWordProgressResponse.model_validate(prog).model_dump() if prog else None
            result.append(d)
        return result, total

    # ===== 真题例句 =====

    async def get_word_examples(self, user_id: str, word_id: str) -> list[dict]:
        r = await self.db.execute(
            select(WordExample)
            .where(WordExample.word_id == word_id)
            .order_by(WordExample.created_at.asc())
        )
        return [
            {
                "id": e.id,
                "example": e.example,
                "translation_cn": e.translation_cn,
                "source": e.source,
            }
            for e in r.scalars().all()
        ]

    async def add_word_example(
        self, user_id: str, word_id: str, example: str, translation_cn: str, source: Optional[str] = None
    ) -> dict:
        word = await self._get_word(word_id)
        self.db.add(WordExample(
            word_id=word_id,
            example=example.strip(),
            translation_cn=translation_cn.strip(),
            source=source,
        ))
        await self.db.flush()
        return {"word_id": word_id, "word": word.word, "ok": True}

    # ===== 四六级词汇标注与内置例句 =====

    async def annotate_cet_words(self, user_id: str) -> dict:
        """启发式标注词汇等级：核心词 / 高频词 / 易错词"""
        r = await self.db.execute(select(VocabularyWord))
        words = list(r.scalars().all())
        updated = 0
        for w in words:
            if not w.exam_type:
                w.exam_type = "CET6" if (w.category or "").upper().find("CET6") >= 0 else "CET4"
            level = "core"
            if w.difficulty and w.difficulty.value == "hard":
                level = "error_prone"
            elif w.difficulty and w.difficulty.value == "easy":
                level = "core"
            else:
                level = "high_freq"
            if w.word_level != level:
                w.word_level = level
                updated += 1
        await self.db.flush()
        return {"total": len(words), "updated": updated}

    async def seed_builtin_examples(self, user_id: str) -> dict:
        """为内置词表写入真题风格例句（幂等）"""
        count = 0
        for word, example, translation, source in BUILTIN_EXAMPLES:
            w = await self._get_word_by_text(word)
            if not w:
                continue
            exists = (await self.db.execute(
                select(WordExample).where(
                    and_(WordExample.word_id == w.id, WordExample.example == example)
                )
            )).scalar_one_or_none()
            if exists:
                continue
            self.db.add(WordExample(
                word_id=w.id,
                example=example,
                translation_cn=translation,
                source=source,
            ))
            count += 1
        await self.db.flush()
        return {"seeded": count}

    async def get_word_detail(self, word_id: str, user_id: str) -> dict:
        r = await self.db.execute(select(VocabularyWord).where(VocabularyWord.id == word_id))
        word = r.scalar_one_or_none()
        if not word: raise ValueError("Word not found")
        d = VocabularyWordResponse.model_validate(word).model_dump()
        prog = await self._get_progress(user_id, word_id)
        d["progress"] = UserWordProgressResponse.model_validate(prog).model_dump() if prog else None
        return d

    # ===== 词库固定音频 =====

    async def ensure_word_audio(self, user_id: str, word_id: str) -> dict:
        """为单词绑定固定音频资源（首次生成后永久复用）"""
        word = await self._get_word(word_id)
        audio_url = await self._ensure_word_audio(word)
        if not audio_url:
            raise ValueError("Audio generation failed")
        return {"word_id": word.id, "word": word.word, "audio_url": audio_url}

    async def warmup_audio(self, user_id: str) -> dict:
        """批量预生成词库音频（限 3 并发），供列表页快速播放"""
        r = await self.db.execute(
            select(VocabularyWord).where(VocabularyWord.audio_url.is_(None))
        )
        words = list(r.scalars().all())
        sem = asyncio.Semaphore(3)

        async def _gen(w: VocabularyWord):
            async with sem:
                await self._ensure_word_audio(w)

        await asyncio.gather(*[_gen(w) for w in words])
        return {
            "total": len(words),
            "generated": sum(1 for w in words if w.audio_url),
        }

    async def _ensure_word_audio(self, word: VocabularyWord) -> str:
        """惰性生成单词音频：合成 MP3 -> 写静态目录 -> 更新 audio_url"""
        if word.audio_url:
            return word.audio_url
        lock = _word_audio_locks.setdefault(word.id, asyncio.Lock())
        async with lock:
            if word.audio_url:
                return word.audio_url
            filename = re.sub(r"[^a-zA-Z0-9\-_]", "", word.word.lower()) or word.id
            rel_path = f"/static/audio/words/{filename}.mp3"
            file_path = os.path.join(_STATIC_AUDIO_DIR, f"{filename}.mp3")
            try:
                os.makedirs(_STATIC_AUDIO_DIR, exist_ok=True)
                if not os.path.exists(file_path):
                    communicate = edge_tts.Communicate(word.word, voice=_AUDIO_VOICE)
                    chunks = []
                    async for chunk in communicate.stream():
                        if chunk["type"] == "audio":
                            chunks.append(chunk["data"])
                    audio = b"".join(chunks)
                    if audio:
                        with open(file_path, "wb") as f:
                            f.write(audio)
                word.audio_url = rel_path
                await self.db.flush()
            except Exception as e:
                print(f"Word audio generation failed for {word.word}: {e}")
                return ""
        return word.audio_url or ""

    async def get_my_progress(self, user_id: str, status: Optional[str] = None) -> list[dict]:
        """见 get_words / get_word_detail：audio_url 随 VocabularyWordResponse 自动返回"""
        query = select(UserWordProgress, VocabularyWord).join(VocabularyWord, UserWordProgress.word_id == VocabularyWord.id).where(UserWordProgress.user_id == user_id)
        if status: query = query.where(UserWordProgress.status == status)
        query = query.order_by(UserWordProgress.next_review_date.asc().nulls_last())
        rows = (await self.db.execute(query)).all()
        result = []
        for prog, word in rows:
            d = VocabularyWordResponse.model_validate(word).model_dump()
            d["progress"] = UserWordProgressResponse.model_validate(prog).model_dump()
            result.append(d)
        return result

    async def start_learning(self, user_id: str, word_id: str) -> dict:
        word = await self._get_word(word_id)
        prog = await self._get_or_create_progress(user_id, word_id)
        if prog.status == WordStatus.NEW:
            prog.status = WordStatus.LEARNING; prog.last_review_date = date.today(); prog.next_review_date = date.today() + timedelta(days=1)
            await self.db.flush(); await self.db.refresh(prog)
            # 真实学习行为：新学单词数 +1
            from app.services.stats_service import StatsService
            await StatsService(self.db).record_activity(user_id, "words_learned", 1)
        d = VocabularyWordResponse.model_validate(word).model_dump()
        d["progress"] = UserWordProgressResponse.model_validate(prog).model_dump()
        return d

    async def review_word(self, user_id: str, word_id: str, correct: bool) -> dict:
        word = await self._get_word(word_id)
        prog = await self._get_or_create_progress(user_id, word_id)
        today = date.today()
        self._apply_sm2(prog, correct, today)
        await self.db.flush(); await self.db.refresh(prog)
        # Auto-record stats
        from app.services.stats_service import StatsService
        ss = StatsService(self.db); await ss.record_activity(user_id, "words_reviewed", 1)
        d = VocabularyWordResponse.model_validate(word).model_dump()
        d["progress"] = UserWordProgressResponse.model_validate(prog).model_dump()
        return d

    # ===== SM-2 复习算法 =====

    @staticmethod
    def _apply_sm2(prog: UserWordProgress, correct: bool, today: date) -> None:
        """根据答题情况动态计算复习间隔（SM-2）：
        - 答对：连续答对次数 +1，间隔按 EF 指数增长；连续 5 次掌握
        - 答错：连续答对清零、EF -0.3、错误次数 +1、次日复习
        """
        prog.review_count = (prog.review_count or 0) + 1
        prev_interval = 0
        if prog.next_review_date and prog.last_review_date:
            prev_interval = (prog.next_review_date - prog.last_review_date).days
        prog.last_review_date = today
        if correct:
            prog.repetition = (prog.repetition or 0) + 1
            prog.ease_factor = max(SM2_MIN_EF, round((prog.ease_factor or SM2_INITIAL_EF) + 0.1, 2))
            if prog.repetition == 1:
                interval = 1
            elif prog.repetition == 2:
                interval = 6
            elif prev_interval > 0:
                interval = max(1, round(prev_interval * (prog.ease_factor or SM2_INITIAL_EF)))
            else:
                interval = max(1, round(7 * (prog.ease_factor or SM2_INITIAL_EF)))
            if prog.repetition >= SM2_MASTER_REPETITION:
                prog.status = WordStatus.MASTERED
                prog.next_review_date = None
            else:
                prog.status = WordStatus.REVIEW
                prog.next_review_date = today + timedelta(days=interval)
        else:
            prog.repetition = 0
            prog.error_count = (prog.error_count or 0) + 1
            prog.ease_factor = max(SM2_MIN_EF, round((prog.ease_factor or SM2_INITIAL_EF) - 0.3, 2))
            prog.status = WordStatus.LEARNING
            prog.next_review_date = today + timedelta(days=1)

    # ===== 生词本 =====

    async def bookmark_word(
        self,
        user_id: str,
        word: str,
        chinese_definition: Optional[str] = None,
        source: str = "manual",
        context: Optional[str] = None,
    ) -> dict:
        """收藏单词：词库不存在时自动创建（支持阅读/AI聊天中收藏）"""
        text = str(word or "").strip()
        if not text:
            raise ValueError("Word is required")
        vocab = await self._get_word_by_text(text)
        if not vocab:
            vocab = VocabularyWord(
                word=text,
                chinese_definition=(chinese_definition or "").strip(),
                difficulty="medium",
            )
            self.db.add(vocab)
            await self.db.flush()
        prog = await self._get_or_create_progress(user_id, vocab.id)
        prog.is_bookmarked = True
        existing = (await self.db.execute(
            select(WordBook).where(
                and_(WordBook.user_id == user_id, WordBook.word_id == vocab.id)
            )
        )).scalar_one_or_none()
        if not existing:
            self.db.add(WordBook(
                user_id=user_id,
                word_id=vocab.id,
                source=source if source in ("manual", "reading", "chat") else "manual",
                source_context=context,
            ))
        await self.db.flush()
        return {"word_id": vocab.id, "word": vocab.word, "bookmarked": True}

    async def unbookmark_word(self, user_id: str, word_id: str) -> dict:
        word = await self._get_word(word_id)
        existing = (await self.db.execute(
            select(WordBook).where(
                and_(WordBook.user_id == user_id, WordBook.word_id == word_id)
            )
        )).scalar_one_or_none()
        if existing:
            await self.db.delete(existing)
        prog = await self._get_progress(user_id, word_id)
        if prog:
            prog.is_bookmarked = False
        await self.db.flush()
        return {"word_id": word_id, "word": word.word, "bookmarked": False}

    async def get_bookmarks(self, user_id: str) -> list[dict]:
        r = await self.db.execute(
            select(WordBook, VocabularyWord)
            .join(VocabularyWord, WordBook.word_id == VocabularyWord.id)
            .where(WordBook.user_id == user_id)
            .order_by(WordBook.created_at.desc())
        )
        result = []
        for book, word in r.all():
            prog = await self._get_progress(user_id, word.id)
            d = VocabularyWordResponse.model_validate(word).model_dump()
            d["progress"] = UserWordProgressResponse.model_validate(prog).model_dump() if prog else None
            d["bookmarked"] = True
            d["bookmark_source"] = book.source
            d["bookmark_context"] = book.source_context
            d["bookmarked_at"] = book.created_at.isoformat()
            result.append(d)
        return result

    async def generate_memory_aid(self, user_id: str, word_id: str) -> dict:
        word = await self._get_word(word_id)
        prog = await self._get_or_create_progress(user_id, word_id)
        # 已有记忆法直接返回（避免重复等待 AI 生成）
        if prog.memory_aid:
            d = VocabularyWordResponse.model_validate(word).model_dump()
            d["progress"] = UserWordProgressResponse.model_validate(prog).model_dump()
            return d
        prompt = MEMORY_AID_PROMPT.format(
            word=word.word,
            exam_type=word.exam_type or "CET4",
            word_level=WORD_LEVEL_CN.get(word.word_level or "", "核心词"),
        )
        try:
            ai_reply = await ai_client.chat(
                messages=[{"role": "user", "content": prompt}],
                temperature=0.7,
                max_tokens=800,
                json_mode=True,
            )
            parsed = self._parse_memory_json(ai_reply)
            stored = json.dumps(parsed, ensure_ascii=False) if parsed else self.clean_markdown_text(ai_reply)
        except Exception:
            stored = f"[{word.word}] AI memory aid unavailable."
        prog.memory_aid = stored
        await self.db.flush(); await self.db.refresh(prog)
        d = VocabularyWordResponse.model_validate(word).model_dump()
        d["progress"] = UserWordProgressResponse.model_validate(prog).model_dump()
        return d

    @staticmethod
    def _parse_memory_json(text: str) -> Optional[dict]:
        """解析记忆卡片 JSON（兼容代码块包裹）"""
        if not text:
            return None
        cleaned = text.strip()
        if cleaned.startswith("```"):
            cleaned = re.sub(r"^```[a-zA-Z]*\n?", "", cleaned)
            cleaned = re.sub(r"\n?```$", "", cleaned)
        try:
            data = json.loads(cleaned)
            if isinstance(data, dict) and "sections" in data:
                return data
        except json.JSONDecodeError:
            pass
        m = re.search(r"\{.*\}", cleaned, re.DOTALL)
        if m:
            try:
                data = json.loads(m.group())
                if isinstance(data, dict) and "sections" in data:
                    return data
            except json.JSONDecodeError:
                pass
        return None

    @staticmethod
    def clean_markdown_text(text: str) -> str:
        """把 AI 输出中的 Markdown 符号清理为纯文本（保留结构）"""
        if not text:
            return ""
        lines = []
        for raw in text.split("\n"):
            line = raw.rstrip()
            stripped = line.strip()
            # 分隔线 --- / *** / ___
            if re.fullmatch(r"[-*_]{3,}", stripped):
                continue
            # 代码块围栏
            if stripped == "```":
                continue
            # 标题符号
            line = re.sub(r"^#{1,6}\s*", "", line)
            # 引用符号
            line = re.sub(r"^>\s?", "", line)
            # 粗体 **x** / 斜体 *x*
            line = re.sub(r"\*\*(.+?)\*\*", r"\1", line)
            line = re.sub(r"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)", r"\1", line)
            # 行内代码 `x`
            line = re.sub(r"`([^`]+)`", r"\1", line)
            lines.append(line)
        result = "\n".join(lines)
        result = re.sub(r"\n{3,}", "\n\n", result)
        return result.strip()

    async def get_summary(self, user_id: str) -> dict:
        r = await self.db.execute(select(UserWordProgress).where(UserWordProgress.user_id == user_id))
        rows = r.scalars().all(); total = len(rows)
        learned = sum(1 for x in rows if x.status != WordStatus.NEW)
        mastered = sum(1 for x in rows if x.status == WordStatus.MASTERED)
        return {
            "total": total,
            "learned_count": learned,
            "mastered_count": mastered,
            "review_count": sum(x.review_count or 0 for x in rows),
            "error_count": sum(x.error_count or 0 for x in rows),
            "bookmarked_count": sum(1 for x in rows if x.is_bookmarked),
            "new_count": sum(1 for x in rows if x.status == WordStatus.NEW),
            "learning": sum(1 for x in rows if x.status == WordStatus.LEARNING),
            "review": sum(1 for x in rows if x.status == WordStatus.REVIEW),
            "mastered": mastered,
            "today_review": sum(1 for x in rows if x.next_review_date and x.next_review_date <= date.today()),
        }

    async def seed_words(self, words: list[dict]) -> int:
        count = 0
        for raw in words:
            w = self._normalize_word(raw)
            if not w.get("word"):
                continue
            existing = (await self.db.execute(select(VocabularyWord).where(VocabularyWord.word == w["word"]))).scalar_one_or_none()
            if existing: continue
            self.db.add(VocabularyWord(**w)); count += 1
        await self.db.flush(); return count

    @staticmethod
    def _normalize_word(raw: dict) -> dict:
        """字段归一化：兼容 meaning/chinese_definition、example/example_sentences 等命名"""
        w = dict(raw or {})
        word = str(w.get("word") or "").strip()
        meaning = w.get("meaning") or w.get("chinese_definition") or w.get("translation") or ""
        if isinstance(meaning, str):
            meaning = meaning.strip()
        example = w.get("example") if w.get("example") is not None else w.get("example_sentences")
        example = VocabularyService._normalize_examples(example)

        category = str(w.get("category") or "CET4").strip().upper()
        difficulty = str(w.get("difficulty") or "").strip()
        difficulty = DIFFICULTY_ALIASES.get(difficulty) or CATEGORY_DEFAULT_DIFFICULTY.get(category, "medium")

        return {
            "word": word,
            "phonetic": w.get("phonetic") or None,
            "part_of_speech": w.get("part_of_speech") or w.get("pos") or None,
            "chinese_definition": meaning,
            "example_sentences": example,
            "difficulty": difficulty,
            "category": category,
        }

    @staticmethod
    def _normalize_examples(example) -> Optional[list]:
        if example is None:
            return None
        if isinstance(example, str):
            text = example.strip()
            if not text:
                return None
            try:
                parsed = json.loads(text)
                if isinstance(parsed, list):
                    example = parsed
                else:
                    example = [{"en": text, "cn": ""}]
            except Exception:
                example = [{"en": text, "cn": ""}]
        if isinstance(example, list):
            result = []
            for item in example:
                if isinstance(item, dict):
                    result.append({"en": str(item.get("en") or ""), "cn": str(item.get("cn") or "")})
                else:
                    result.append({"en": str(item), "cn": ""})
            return result if result else None
        return None

    # ===== 单词测试系统 =====

    async def generate_test(self, user_id: str, test_type: str, count: int = 5) -> dict:
        """生成测试题目: choice 选择题 / spelling 拼写 / listening 听音"""
        # 从用户学习中的单词选取
        r = await self.db.execute(
            select(VocabularyWord).join(UserWordProgress, UserWordProgress.word_id == VocabularyWord.id)
            .where(UserWordProgress.user_id == user_id)
            .order_by(func.random()).limit(min(count, 10))
        )
        words = r.scalars().all()
        if len(words) < count:
            r2 = await self.db.execute(select(VocabularyWord).order_by(func.random()).limit(count - len(words)))
            words.extend(r2.scalars().all())

        questions = []
        for w in words[:count]:
            if test_type == "choice":
                # 3 个干扰项
                r3 = await self.db.execute(select(VocabularyWord).where(VocabularyWord.id != w.id).order_by(func.random()).limit(3))
                distractor_words = r3.scalars().all()
                options = [w.chinese_definition] + [d.chinese_definition for d in distractor_words]
                random.shuffle(options)
                questions.append({
                    "word": w.word, "phonetic": w.phonetic, "correct": w.chinese_definition,
                    "options": options, "word_id": w.id, "audio_url": w.audio_url,
                })
            elif test_type == "spelling":
                questions.append({"word_id": w.id, "meaning": w.chinese_definition, "correct": w.word, "audio_url": w.audio_url})
            else:  # listening
                r3 = await self.db.execute(select(VocabularyWord).where(VocabularyWord.id != w.id).order_by(func.random()).limit(3))
                distractor_words = r3.scalars().all()
                options = [w.chinese_definition] + [d.chinese_definition for d in distractor_words]
                random.shuffle(options)
                questions.append({"word": w.word, "correct": w.chinese_definition, "options": options, "word_id": w.id, "audio_url": w.audio_url})
        return {"test_type": test_type, "questions": questions}

    async def submit_test(self, user_id: str, test_type: str, answers: list[dict]) -> dict:
        """提交测试答案，记录结果"""
        correct_count = 0; results = []
        today = date.today()
        for ans in answers:
            word_id = ans.get("word_id"); user_answer = ans.get("answer", "")
            r = await self.db.execute(select(VocabularyWord).where(VocabularyWord.id == word_id))
            w = r.scalar_one_or_none()
            if not w: continue
            is_correct = str(user_answer).strip().lower() == w.chinese_definition.strip().lower() if test_type != "spelling" else str(user_answer).strip().lower() == w.word.strip().lower()
            if is_correct: correct_count += 1
            # 测试结果影响学习状态：答对提高熟练度，答错降低熟练度
            prog = await self._get_or_create_progress(user_id, word_id)
            self._apply_sm2(prog, is_correct, today)
            results.append({"word_id": word_id, "word": w.word, "user_answer": user_answer, "correct": w.chinese_definition if test_type != "spelling" else w.word, "is_correct": is_correct})
        total = len(results)
        record = TestRecord(user_id=user_id, test_type=test_type, score=correct_count, total=total, results=results)
        await self.db.flush()
        # 测验也是真实单词练习：按答题数累计复习量
        from app.services.stats_service import StatsService
        await StatsService(self.db).record_activity(user_id, "words_reviewed", total)
        return {"score": correct_count, "total": total, "accuracy": round(correct_count/total*100) if total else 0, "results": results}

    async def get_test_history(self, user_id: str, page: int = 1, page_size: int = 10) -> tuple[list[dict], int]:
        count_q = select(func.count()).select_from(select(TestRecord).where(TestRecord.user_id == user_id).subquery())
        total = (await self.db.execute(count_q)).scalar() or 0
        r = await self.db.execute(select(TestRecord).where(TestRecord.user_id == user_id).order_by(TestRecord.created_at.desc()).offset((page-1)*page_size).limit(page_size))
        rows = r.scalars().all()
        items = [{"id": x.id, "test_type": x.test_type, "score": x.score, "total": x.total, "accuracy": round(x.score/x.total*100) if x.total else 0, "created_at": x.created_at.isoformat()} for x in rows]
        return items, total

    async def _get_word(self, word_id: str) -> VocabularyWord:
        r = await self.db.execute(select(VocabularyWord).where(VocabularyWord.id == word_id)); w = r.scalar_one_or_none()
        if not w: raise ValueError("Word not found")
        return w

    async def _get_word_by_text(self, word: str) -> Optional[VocabularyWord]:
        r = await self.db.execute(
            select(VocabularyWord).where(func.lower(VocabularyWord.word) == word.lower())
        )
        return r.scalar_one_or_none()

    async def _get_progress(self, user_id: str, word_id: str) -> Optional[UserWordProgress]:
        r = await self.db.execute(select(UserWordProgress).where(UserWordProgress.user_id == user_id, UserWordProgress.word_id == word_id))
        return r.scalar_one_or_none()

    async def _get_or_create_progress(self, user_id: str, word_id: str) -> UserWordProgress:
        prog = await self._get_progress(user_id, word_id)
        if not prog: prog = UserWordProgress(user_id=user_id, word_id=word_id); self.db.add(prog); await self.db.flush()
        return prog
