# api/v1/cet_writing.py - 四六级作文训练 + 模板库 API

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, get_current_user_id
from app.services.cet_writing_service import CetWritingService

router = APIRouter(prefix="/cet/writing", tags=["CET Writing"])


class EssayRequest(BaseModel):
    essay: str = Field(..., min_length=10, max_length=3000)
    exam_type: str = Field("CET4", description="CET4 / CET6")


class TemplateRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=100)
    content: str = Field(..., min_length=1)
    category: str | None = None


class AiTemplateRequest(BaseModel):
    exam_type: str = "CET4"
    category: str = "议论文"


@router.post("/review")
async def review_essay(
    req: EssayRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """四六级作文批改（满分 15 分）"""
    exam_type = req.exam_type.upper()
    if exam_type not in ("CET4", "CET6"):
        raise HTTPException(status_code=400, detail="exam_type must be CET4 or CET6")
    return await CetWritingService(db).review_essay(user_id, req.essay, exam_type)


@router.get("/templates")
async def get_templates(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """我的作文模板（含 AI 推荐）"""
    return await CetWritingService(db).get_templates(user_id)


@router.post("/templates")
async def create_template(
    req: TemplateRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """保存我的作文模板"""
    svc = CetWritingService(db)
    try:
        return await svc.create_template(user_id, req.title, req.content, req.category)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/templates/{template_id}")
async def delete_template(
    template_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """删除作文模板"""
    try:
        await CetWritingService(db).delete_template(user_id, template_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return {"message": "deleted"}


@router.post("/templates/ai-recommend")
async def ai_recommend(
    req: AiTemplateRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """AI 生成推荐作文模板"""
    exam_type = req.exam_type.upper()
    try:
        return await CetWritingService(db).ai_recommend_template(
            user_id, exam_type, req.category
        )
    except ValueError as e:
        raise HTTPException(status_code=502, detail=str(e))
