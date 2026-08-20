# api/v1/backup.py - 数据备份 API

from fastapi import APIRouter, Body, Depends, HTTPException
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_db, get_current_user_id
from app.services.backup_service import BackupService

router = APIRouter(prefix="/backup", tags=["Backup"])


@router.get("/export")
async def export_data(user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    """导出用户全部学习数据为 JSON"""
    data = await BackupService(db).export_all(user_id)
    return JSONResponse(content=data)


@router.post("/restore")
async def restore_data(payload: dict = Body(...), user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    """从导出的 JSON 恢复用户学习数据"""
    if not payload or not isinstance(payload, dict) or not any(k in payload for k in ("chat_history", "word_progress", "reading_records", "writing_records", "daily_stats")):
        raise HTTPException(status_code=400, detail="备份数据为空或格式不正确")
    result = await BackupService(db).restore_all(user_id, payload)
    return result
