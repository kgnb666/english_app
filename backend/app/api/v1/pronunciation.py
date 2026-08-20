# api/v1/pronunciation.py - 发音评测 API

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, get_current_user_id
from app.services.pronunciation_service import PronunciationService

router = APIRouter(prefix="/pronunciation", tags=["Pronunciation"])


class EvaluateRequest(BaseModel):
    target_text: str = Field(..., min_length=1, max_length=500)
    recognized_text: str = Field("", max_length=500)
    confidence: float | None = Field(None, ge=0, le=1)


@router.post("/evaluate")
async def evaluate(
    req: EvaluateRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """发音评测：识别文本 + 目标句对比评分，AI 生成错误音节与建议"""
    try:
        return await PronunciationService(db).evaluate(
            user_id, req.target_text, req.recognized_text, req.confidence
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/history")
async def get_history(
    limit: int = Query(20, ge=1, le=100),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """发音评测历史"""
    return await PronunciationService(db).get_history(user_id, limit)
