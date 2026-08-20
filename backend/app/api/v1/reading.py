# api/v1/reading.py - Reading Assistant API with history

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field
from app.core.dependencies import get_db, get_current_user_id
from app.services.reading_service import ReadingService

router = APIRouter(prefix="/reading", tags=["Reading Assistant"])


class AnalyzeRequest(BaseModel):
    article: str = Field(..., min_length=10, max_length=3000)


@router.post("/analyze")
async def analyze_article(req: AnalyzeRequest, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    svc = ReadingService(db)
    try: return await svc.analyze(req.article, user_id)
    except Exception as e: raise HTTPException(status_code=500, detail=str(e))


@router.get("/history")
async def get_history(user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db), page: int = Query(1, ge=1), page_size: int = Query(10, ge=1, le=50)):
    svc = ReadingService(db)
    items, total = await svc.get_history(user_id, page, page_size)
    return {"items": items, "total": total, "page": page}


@router.get("/history/{record_id}")
async def get_history_detail(record_id: str, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    svc = ReadingService(db)
    try:
        return await svc.get_record_detail(user_id, record_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/history/{record_id}")
async def delete_history_record(record_id: str, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    svc = ReadingService(db)
    try:
        await svc.delete_record(user_id, record_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return {"message": "deleted"}
