# api/v1/chat.py - AI 对话 API

import json

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_db, get_current_user_id
from app.schemas.chat import ChatMessageRequest, ChatMessageResponse, ChatSessionResponse, ChatSessionDetailResponse
from app.services.chat_service import ChatService, AIServiceError
from app.models.chat import ChatSession

router = APIRouter(prefix="/chat", tags=["AI Speaking Coach"])


@router.post("/sessions", response_model=ChatSessionResponse, status_code=201)
async def create_session(topic: str | None = None, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    return await ChatService(db).create_session(user_id, topic)


@router.get("/sessions", response_model=list[ChatSessionResponse])
async def list_sessions(user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    return await ChatService(db).list_sessions(user_id)


@router.get("/topics")
async def get_topics(user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    """根据用户等级动态推荐聊天主题"""
    return await ChatService(db).get_recommended_topics(user_id)


@router.get("/sessions/{session_id}", response_model=ChatSessionDetailResponse)
async def get_session(session_id: str, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    svc = ChatService(db)
    try: return await svc.get_session_detail(session_id, user_id)
    except ValueError as e: raise HTTPException(status_code=404, detail=str(e))


@router.delete("/sessions/{session_id}", status_code=204)
async def delete_session(session_id: str, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    svc = ChatService(db)
    try: await svc.delete_session(session_id, user_id)
    except ValueError as e: raise HTTPException(status_code=404, detail=str(e))


@router.post("/sessions/{session_id}/messages", response_model=ChatMessageResponse, status_code=201)
async def send_message(session_id: str, req: ChatMessageRequest, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    svc = ChatService(db)
    try:
        return await svc.send_message(session_id, user_id, req.content)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except AIServiceError:
        # 用户消息已保存，提交后返回可重试的结构化错误
        await db.commit()
        raise HTTPException(
            status_code=503,
            detail={"type": "ai_unavailable", "retryable": True},
        )


@router.post("/sessions/{session_id}/messages/stream")
async def send_message_stream(session_id: str, req: ChatMessageRequest, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    """流式对话：SSE 事件（chunk / corrections / done / error）"""
    r = await db.execute(select(ChatSession).where(
        ChatSession.id == session_id, ChatSession.user_id == user_id
    ))
    if not r.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Session not found")
    svc = ChatService(db)
    gen = svc.stream_message(session_id, user_id, req.content)

    async def event_stream():
        async for event in gen:
            yield f"data: {json.dumps(event, ensure_ascii=False)}\n\n"

    return StreamingResponse(event_stream(), media_type="text/event-stream")


@router.post("/sessions/{session_id}/summary")
async def session_summary(session_id: str, user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    """AI 生成会话总结"""
    try:
        return await ChatService(db).generate_summary(session_id, user_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except AIServiceError:
        raise HTTPException(status_code=503, detail={"type": "ai_unavailable", "retryable": True})
