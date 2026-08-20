# api/v1/stats.py - 学习统计 API

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, get_current_user_id
from app.services.stats_service import StatsService

router = APIRouter(prefix="/stats", tags=["Statistics"])


class StudySessionStartRequest(BaseModel):
    session_type: str = Field(..., description="chat / words / reading / writing")


class StudySessionEndRequest(BaseModel):
    duration_seconds: int = Field(..., ge=0, description="客户端统计的实际学习秒数")


@router.get("/dashboard")
async def get_dashboard(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """首页仪表盘数据"""
    svc = StatsService(db)
    return await svc.get_dashboard(user_id)


@router.get("/weekly")
async def get_weekly(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """近7天每日统计"""
    svc = StatsService(db)
    return await svc.get_weekly_stats(user_id)


@router.get("/monthly")
async def get_monthly(
    year: int = Query(..., ge=2000, le=2100),
    month: int = Query(..., ge=1, le=12),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """月度统计：当月汇总 + 每日明细"""
    svc = StatsService(db)
    return await svc.get_monthly_stats(user_id, year, month)


@router.get("/calendar")
async def get_calendar(
    year: int = Query(..., ge=2000, le=2100),
    month: int = Query(..., ge=1, le=12),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """学习日历：当月每天学习情况"""
    svc = StatsService(db)
    return await svc.get_calendar_stats(user_id, year, month)


@router.post("/sessions")
async def start_session(
    req: StudySessionStartRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """开始一次真实学习计时"""
    svc = StatsService(db)
    try:
        return await svc.start_study_session(user_id, req.session_type)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/sessions/{session_id}/end")
async def end_session(
    session_id: str,
    req: StudySessionEndRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """结束学习计时并按真实时长累计统计"""
    svc = StatsService(db)
    try:
        return await svc.end_study_session(user_id, session_id, req.duration_seconds)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/record")
async def record_activity(
    activity_type: str,
    amount: int = 1,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """记录学习活动"""
    svc = StatsService(db)
    await svc.record_activity(user_id, activity_type, amount)
    return {"ok": True}
