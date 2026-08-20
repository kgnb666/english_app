# api/v1/cet_reading.py - 四六级阅读专项训练 API

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, get_current_user_id
from app.services.cet_reading_service import CetReadingService

router = APIRouter(prefix="/cet/reading", tags=["CET Reading"])


class SubmitRequest(BaseModel):
    exam_type: str
    article_id: str
    answers: list[dict]


@router.get("/articles")
async def get_articles(
    exam_type: str = Query("CET4"),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """四六级阅读文章列表"""
    return CetReadingService(db).get_articles(exam_type)


@router.get("/articles/{article_id}")
async def get_article(
    article_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """文章详情与题目（不含答案）"""
    try:
        return CetReadingService(db).get_article(article_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/submit")
async def submit(
    req: SubmitRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """提交阅读答案，AI 生成分析并保存记录"""
    try:
        return await CetReadingService(db).submit(
            user_id, req.exam_type, req.article_id, req.answers
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/history")
async def get_history(
    limit: int = Query(20, ge=1, le=100),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """阅读训练历史"""
    return await CetReadingService(db).get_history(user_id, limit)


@router.get("/history/{record_id}")
async def get_record(
    record_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """阅读记录详情（含 AI 分析）"""
    try:
        return await CetReadingService(db).get_record_detail(user_id, record_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
