# api/v1/cet_translation.py - 四六级翻译训练 API

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, get_current_user_id
from app.services.cet_translation_service import CetTranslationService

router = APIRouter(prefix="/cet/translation", tags=["CET Translation"])


class SubmitRequest(BaseModel):
    exam_type: str = "CET4"
    sentence_id: str
    chinese_text: str | None = None
    user_translation: str = Field(..., min_length=1, max_length=2000)


@router.get("/sentences")
async def get_sentences(
    exam_type: str = Query("CET4"),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """翻译练习句子（中文）"""
    return CetTranslationService(db).get_sentences(exam_type)


@router.post("/submit")
async def submit(
    req: SubmitRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """提交翻译，AI 评分（词汇/语序/自然度）"""
    exam_type = req.exam_type.upper()
    try:
        return await CetTranslationService(db).submit(
            user_id, exam_type, req.sentence_id, req.chinese_text or "", req.user_translation
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/history")
async def get_history(
    limit: int = Query(20, ge=1, le=100),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """翻译练习历史"""
    return await CetTranslationService(db).get_history(user_id, limit)
