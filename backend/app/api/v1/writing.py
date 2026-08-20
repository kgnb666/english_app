# api/v1/writing.py - Essay Review API with history

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field
from app.core.dependencies import get_db, get_current_user_id
from app.services.writing_service import WritingService

router = APIRouter(prefix="/writing", tags=["Writing"])


class EssayRequest(BaseModel):
    essay: str = Field(..., min_length=10, max_length=3000)


@router.post("/review")
async def review_essay(req: EssayRequest, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    svc = WritingService(db)
    try: return await svc.review(req.essay, user_id)
    except Exception as e: raise HTTPException(status_code=500, detail=str(e))


@router.get("/history")
async def get_history(user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db), page: int = Query(1, ge=1), page_size: int = Query(10, ge=1, le=50)):
    svc = WritingService(db)
    items, total = await svc.get_history(user_id, page, page_size)
    return {"items": items, "total": total, "page": page}


@router.get("/history/{record_id}")
async def get_history_detail(record_id: str, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    svc = WritingService(db)
    try:
        return await svc.get_record_detail(user_id, record_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/history/{record_id}")
async def delete_history_record(record_id: str, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    svc = WritingService(db)
    try:
        await svc.delete_record(user_id, record_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return {"message": "deleted"}
