# api/v1/cet.py - 四六级专项学习 API

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, get_current_user_id
from app.schemas.cet import CetGoalRequest
from app.services.cet_service import CetService

router = APIRouter(prefix="/cet", tags=["CET Study"])


@router.get("/dashboard")
async def get_dashboard(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """四六级目标、阶段计划、今日任务总览"""
    return await CetService(db).get_dashboard(user_id)


@router.put("/goal")
async def set_goal(
    req: CetGoalRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """设置四六级目标并生成阶段计划"""
    try:
        return await CetService(db).set_goal(
            user_id, req.exam_type, req.target_score, req.exam_date, req.daily_minutes
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/goal")
async def cancel_goal(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """取消四六级目标，恢复默认学习计划"""
    return await CetService(db).cancel_goal(user_id)
