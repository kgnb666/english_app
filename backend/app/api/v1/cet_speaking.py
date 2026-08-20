# api/v1/cet_speaking.py - 四六级 AI 口语考试模拟 API

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, get_current_user_id
from app.services.cet_speaking_service import CetSpeakingService

router = APIRouter(prefix="/cet/speaking", tags=["CET Speaking"])


class SubmitRequest(BaseModel):
    exam_type: str = "CET4"
    question: str = Field(..., min_length=1)
    user_answer: str = Field(..., min_length=1, max_length=2000)


@router.get("/questions")
async def get_questions(
    exam_type: str = Query("CET4"),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """口语考试问题"""
    return CetSpeakingService(db).get_questions(exam_type)


@router.post("/submit")
async def submit(
    req: SubmitRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """提交口语回答（语音转写文本），AI 四维评分"""
    try:
        return await CetSpeakingService(db).submit(
            user_id, req.exam_type, req.question, req.user_answer
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/history")
async def get_history(
    limit: int = Query(20, ge=1, le=100),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """口语练习历史"""
    return await CetSpeakingService(db).get_history(user_id, limit)
