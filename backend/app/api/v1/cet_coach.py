# api/v1/cet_coach.py - 四六级 AI 私人教练 API

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, get_current_user_id
from app.services.cet_coach_service import CetCoachService

router = APIRouter(prefix="/cet/coach", tags=["CET Coach"])


@router.get("/profile")
async def get_profile(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """AI 教练画像：弱项、错误类型、历史成绩、词汇掌握"""
    return await CetCoachService(db).get_profile(user_id)


@router.get("/suggestion")
async def get_suggestion(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """今日 AI 学习建议（当日缓存，基于学习历史自动生成并调整计划）"""
    return await CetCoachService(db).get_daily_suggestion(user_id)
