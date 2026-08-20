# api/v1/vocabulary.py - 单词学习 + 测试 API

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from app.core.dependencies import get_db, get_current_user_id
from app.services.vocabulary_service import VocabularyService
from app.schemas.vocabulary import SeedWordsRequest

router = APIRouter(prefix="/vocabulary", tags=["Vocabulary"])


class TestSubmitRequest(BaseModel):
    test_type: str
    answers: list[dict]


class BookmarkRequest(BaseModel):
    word: str
    chinese_definition: str | None = None
    source: str = "manual"  # manual / reading / chat
    context: str | None = None


class WordExampleRequest(BaseModel):
    example: str
    translation_cn: str
    source: str | None = None


@router.get("/words")
async def list_words(status: str | None = None, category: str | None = None, search: str | None = None, exam_type: str | None = None, word_level: str | None = None, page: int = 1, page_size: int = 20, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    svc = VocabularyService(db)
    items, total = await svc.get_words(user_id, status, category, search, page, page_size, exam_type, word_level)
    return {"items": items, "total": total, "page": page, "page_size": page_size}


@router.get("/words/{word_id}")
async def get_word(word_id: str, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    svc = VocabularyService(db)
    try: return await svc.get_word_detail(word_id, user_id)
    except ValueError as e: raise HTTPException(status_code=404, detail=str(e))


@router.get("/words/{word_id}/examples")
async def get_word_examples(word_id: str, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    """四六级真题例句列表"""
    return await VocabularyService(db).get_word_examples(user_id, word_id)


@router.post("/words/{word_id}/examples")
async def add_word_example(word_id: str, req: WordExampleRequest, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    """录入真题例句"""
    svc = VocabularyService(db)
    try:
        return await svc.add_word_example(user_id, word_id, req.example, req.translation_cn, req.source)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/cet/annotate")
async def annotate_cet_words(user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    """标注四六级词汇等级（核心/高频/易错）"""
    return await VocabularyService(db).annotate_cet_words(user_id)


@router.post("/cet/seed-examples")
async def seed_builtin_examples(user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    """写入内置四六级真题例句（幂等）"""
    return await VocabularyService(db).seed_builtin_examples(user_id)


@router.get("/my-progress")
async def get_progress(status: str | None = None, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    return await VocabularyService(db).get_my_progress(user_id, status)


@router.post("/words/{word_id}/start")
async def start_learning(word_id: str, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    svc = VocabularyService(db)
    try: return await svc.start_learning(user_id, word_id)
    except ValueError as e: raise HTTPException(status_code=404, detail=str(e))


@router.post("/words/{word_id}/review")
async def review_word(word_id: str, correct: bool = True, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    svc = VocabularyService(db)
    try: return await svc.review_word(user_id, word_id, correct)
    except ValueError as e: raise HTTPException(status_code=404, detail=str(e))


@router.post("/words/{word_id}/memory-aid")
async def generate_memory_aid(word_id: str, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    svc = VocabularyService(db)
    try: return await svc.generate_memory_aid(user_id, word_id)
    except ValueError as e: raise HTTPException(status_code=404, detail=str(e))


@router.post("/words/{word_id}/audio")
async def ensure_word_audio(word_id: str, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    """为单词生成并绑定固定音频资源，返回 audio_url"""
    svc = VocabularyService(db)
    try: return await svc.ensure_word_audio(user_id, word_id)
    except ValueError as e: raise HTTPException(status_code=404, detail=str(e))


@router.post("/audio/warmup")
async def warmup_audio(user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    """批量预生成词库音频"""
    return await VocabularyService(db).warmup_audio(user_id)


@router.get("/summary")
async def get_summary(user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    return await VocabularyService(db).get_summary(user_id)


@router.get("/bookmarks")
async def get_bookmarks(user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    """生词本列表"""
    return await VocabularyService(db).get_bookmarks(user_id)


@router.post("/bookmark")
async def bookmark_word(req: BookmarkRequest, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    """收藏单词（词库不存在时自动创建），支持 reading / chat 来源"""
    svc = VocabularyService(db)
    try:
        return await svc.bookmark_word(
            user_id, req.word, req.chinese_definition, req.source, req.context
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/bookmark/{word_id}")
async def unbookmark_word(word_id: str, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    """取消收藏"""
    svc = VocabularyService(db)
    try:
        return await svc.unbookmark_word(user_id, word_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/seed", status_code=201)
async def seed_words(req: SeedWordsRequest | None = None, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    """批量导入单词。
    请求体: {"words": [{word, phonetic, part_of_speech, meaning/chinese_definition, example/example_sentences, difficulty, category}, ...]}
    不带请求体时保持向后兼容，写入内置测试词表。
    """
    svc = VocabularyService(db)
    if req is not None:
        words = [item.model_dump(exclude_none=True) for item in req.words]
    else:
        words = DEFAULT_SEED_WORDS
    count = await svc.seed_words(words)
    return {"message": "done", "total": len(words), "added": count}


DEFAULT_SEED_WORDS = [
    {"word": "abandon", "phonetic": "/əˈbændən/", "part_of_speech": "v.", "chinese_definition": "放弃；抛弃", "example_sentences": [{"en": "He abandoned his plan to travel.", "cn": "他放弃了旅行计划。"}], "difficulty": "easy", "category": "CET4"},
    {"word": "ability", "phonetic": "/əˈbɪləti/", "part_of_speech": "n.", "chinese_definition": "能力；才能", "example_sentences": [{"en": "She has the ability to solve complex problems.", "cn": "她有能力解决复杂问题。"}], "difficulty": "easy", "category": "CET4"},
    {"word": "abroad", "phonetic": "/əˈbrɔːd/", "part_of_speech": "adv.", "chinese_definition": "在国外；到国外", "example_sentences": [{"en": "He dreams of studying abroad.", "cn": "他梦想出国留学。"}], "difficulty": "easy", "category": "CET4"},
    {"word": "absence", "phonetic": "/ˈæbsəns/", "part_of_speech": "n.", "chinese_definition": "缺席；不在", "example_sentences": [{"en": "His absence was noticed by everyone.", "cn": "他的缺席被大家注意到了。"}], "difficulty": "easy", "category": "CET4"},
    {"word": "absolute", "phonetic": "/ˈæbsəluːt/", "part_of_speech": "adj.", "chinese_definition": "绝对的；完全的", "example_sentences": [{"en": "I have absolute confidence in you.", "cn": "我对你有绝对的信心。"}], "difficulty": "easy", "category": "CET4"},
    {"word": "absorb", "phonetic": "/əbˈzɔːrb/", "part_of_speech": "v.", "chinese_definition": "吸收；吸引", "example_sentences": [{"en": "Plants absorb sunlight for energy.", "cn": "植物吸收阳光获取能量。"}], "difficulty": "medium", "category": "CET4"},
    {"word": "abstract", "phonetic": "/ˈæbstrækt/", "part_of_speech": "adj.", "chinese_definition": "抽象的；摘要", "example_sentences": [{"en": "The concept is too abstract to understand.", "cn": "这个概念太抽象了。"}], "difficulty": "medium", "category": "CET4"},
    {"word": "abundant", "phonetic": "/əˈbʌndənt/", "part_of_speech": "adj.", "chinese_definition": "丰富的；充裕的", "example_sentences": [{"en": "The region has abundant natural resources.", "cn": "该地区有丰富的自然资源。"}], "difficulty": "medium", "category": "CET4"},
    {"word": "academic", "phonetic": "/ˌækəˈdemɪk/", "part_of_speech": "adj.", "chinese_definition": "学术的；学院的", "example_sentences": [{"en": "She published several academic papers.", "cn": "她发表了几篇学术论文。"}], "difficulty": "medium", "category": "CET4"},
    {"word": "accelerate", "phonetic": "/əkˈseləreɪt/", "part_of_speech": "v.", "chinese_definition": "加速；促进", "example_sentences": [{"en": "The car accelerated quickly.", "cn": "汽车快速加速。"}], "difficulty": "medium", "category": "CET4"},
]


# ===== 测试系统 =====

@router.get("/test/generate")
async def generate_test(test_type: str = "choice", count: int = 5, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    svc = VocabularyService(db)
    return await svc.generate_test(user_id, test_type, count)


@router.post("/test/submit")
async def submit_test(req: TestSubmitRequest, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    svc = VocabularyService(db)
    return await svc.submit_test(user_id, req.test_type, req.answers)


@router.get("/test/history")
async def get_test_history(page: int = 1, page_size: int = 10, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    svc = VocabularyService(db)
    items, total = await svc.get_test_history(user_id, page, page_size)
    return {"items": items, "total": total}
