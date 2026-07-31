# api/v1/chat.py - AI 口语陪练 API 端点

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, get_current_user_id
from app.schemas.chat import (
    ChatMessageRequest,
    ChatMessageResponse,
    ChatSessionResponse,
    ChatSessionDetailResponse,
)
from app.services.chat_service import ChatService

router = APIRouter(prefix="/chat", tags=["AI Speaking Coach"])


@router.post("/sessions", response_model=ChatSessionResponse, status_code=status.HTTP_201_CREATED)
async def create_session(
    topic: str | None = None,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """创建新的对话会话 (可选指定话题)"""
    service = ChatService(db)
    return await service.create_session(user_id, topic)


@router.get("/sessions", response_model=list[ChatSessionResponse])
async def list_sessions(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """获取当前用户的全部会话列表"""
    service = ChatService(db)
    return await service.list_sessions(user_id)


@router.get("/sessions/{session_id}", response_model=ChatSessionDetailResponse)
async def get_session(
    session_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """获取会话详情 (含全部消息)"""
    service = ChatService(db)
    try:
        return await service.get_session_detail(session_id, user_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_session(
    session_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """删除会话及所有消息"""
    service = ChatService(db)
    try:
        await service.delete_session(session_id, user_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))


@router.post(
    "/sessions/{session_id}/messages",
    response_model=ChatMessageResponse,
    status_code=status.HTTP_201_CREATED,
)
async def send_message(
    session_id: str,
    req: ChatMessageRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """发送消息并获取 AI 教练回复 (含语法纠错)"""
    service = ChatService(db)
    try:
        return await service.send_message(session_id, user_id, req.content)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"AI service error: {str(e)}",
        )
