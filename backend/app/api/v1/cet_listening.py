# api/v1/cet_listening.py - 四六级听力训练 API

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, get_current_user_id
from app.services.cet_listening_service import CetListeningService

router = APIRouter(prefix="/cet/listening", tags=["CET Listening"])


class SubmitRequest(BaseModel):
    exam_type: str
    item_id: str
    answers: list[dict]


@router.get("/items")
async def get_items(
    exam_type: str = Query("CET4"),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """听力材料列表"""
    return CetListeningService(db).get_items(exam_type)


@router.get("/items/{item_id}")
async def get_item(
    item_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """听力材料详情（文本 + 音频 + 题目）"""
    try:
        return await CetListeningService(db).get_item(item_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/submit")
async def submit(
    req: SubmitRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """提交听力答案，AI 逐句解析"""
    try:
        return await CetListeningService(db).submit(
            user_id, req.exam_type, req.item_id, req.answers
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/history")
async def get_history(
    limit: int = Query(20, ge=1, le=100),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """听力训练历史"""
    return await CetListeningService(db).get_history(user_id, limit)
