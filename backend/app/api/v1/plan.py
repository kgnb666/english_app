# api/v1/plan.py - 学习计划 API

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, get_current_user_id
from app.services.plan_service import PlanService

router = APIRouter(prefix="/plan", tags=["Learning Plan"])


class PlanTaskItem(BaseModel):
    task_type: str
    target_count: int = Field(ge=0)
    enabled: bool = True


class PlanUpdateRequest(BaseModel):
    tasks: list[PlanTaskItem]


@router.get("/today")
async def get_today_tasks(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """今日任务（自动生成，完成进度来自真实学习数据）"""
    return await PlanService(db).get_today_tasks(user_id)


@router.get("")
async def get_plan(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """当前学习计划模板"""
    return await PlanService(db).get_plan(user_id)


@router.put("")
async def update_plan(
    req: PlanUpdateRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """更新学习计划模板"""
    return await PlanService(db).update_plan(
        user_id, [item.model_dump() for item in req.tasks]
    )
