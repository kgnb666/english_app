# api/v1/profile.py - 用户学习画像 + 错误记录 API

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, get_current_user_id
from app.schemas.profile import ProfileUpdateRequest
from app.services.profile_service import ProfileService

router = APIRouter(prefix="/profile", tags=["User Profile"])


@router.get("")
async def get_profile(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """获取用户学习画像"""
    return await ProfileService(db).get_profile(user_id)


@router.put("")
async def update_profile(
    req: ProfileUpdateRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """更新用户学习画像"""
    return await ProfileService(db).update_profile(
        user_id, req.model_dump(exclude_unset=True)
    )


@router.get("/errors")
async def get_errors(
    limit: int = Query(50, ge=1, le=200),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """用户错误记录列表（含类型聚合摘要）"""
    svc = ProfileService(db)
    return {
        "items": await svc.get_error_log(user_id, limit),
        "summary": await svc.get_error_summary(user_id),
    }


@router.delete("/errors/{error_id}")
async def delete_error(
    error_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """删除一条错误记录"""
    try:
        await ProfileService(db).delete_error(user_id, error_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return {"message": "deleted"}
