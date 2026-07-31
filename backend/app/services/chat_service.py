# services/chat_service.py - AI 对话服务：会话管理 + AI 调用 + 语法纠错

import re
from datetime import datetime
from typing import Optional

from sqlalchemy import select, desc, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.chat import ChatSession, ChatMessage, MessageRole
from app.models.user import User
from app.ai.client import ai_client
from app.ai.prompts import SPEAKING_COACH_PROMPT
from app.schemas.chat import (
    ChatMessageResponse,
    ChatSessionResponse,
    ChatSessionDetailResponse,
)


class ChatService:
    """AI 口语陪练服务"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_session(self, user_id: str, topic: Optional[str] = None) -> ChatSessionResponse:
        title = topic or "Free Talk"
        session = ChatSession(user_id=user_id, title=title, topic=topic)
        self.db.add(session)
        await self.db.flush()
        await self.db.refresh(session)
        return ChatSessionResponse.model_validate(session)

    async def list_sessions(self, user_id: str) -> list[ChatSessionResponse]:
        result = await self.db.execute(
            select(ChatSession)
            .where(ChatSession.user_id == user_id)
            .order_by(desc(ChatSession.updated_at))
        )
        sessions = result.scalars().all()
        return [ChatSessionResponse.model_validate(s) for s in sessions]

    async def get_session_detail(self, session_id: str, user_id: str) -> ChatSessionDetailResponse:
        result = await self.db.execute(
            select(ChatSession).where(
                ChatSession.id == session_id, ChatSession.user_id == user_id
            )
        )
        session = result.scalar_one_or_none()
        if not session:
            raise ValueError("Session not found")

        messages_result = await self.db.execute(
            select(ChatMessage)
            .where(ChatMessage.session_id == session_id)
            .order_by(ChatMessage.created_at)
        )
        messages = messages_result.scalars().all()
        msg_responses = [ChatMessageResponse.model_validate(m) for m in messages]

        return ChatSessionDetailResponse(
            id=session.id, title=session.title, topic=session.topic,
            messages=msg_responses,
            created_at=session.created_at, updated_at=session.updated_at,
        )

    async def delete_session(self, session_id: str, user_id: str):
        result = await self.db.execute(
            select(ChatSession).where(
                ChatSession.id == session_id, ChatSession.user_id == user_id
            )
        )
        session = result.scalar_one_or_none()
        if not session:
            raise ValueError("Session not found")
        # SQLite 不自动级联，先手动删除关联消息
        await self.db.execute(
            delete(ChatMessage).where(ChatMessage.session_id == session_id)
        )
        await self.db.flush()
        await self.db.delete(session)
        await self.db.flush()

    async def send_message(self, session_id: str, user_id: str, content: str) -> ChatMessageResponse:
        result = await self.db.execute(
            select(ChatSession).where(
                ChatSession.id == session_id, ChatSession.user_id == user_id
            )
        )
        session = result.scalar_one_or_none()
        if not session:
            raise ValueError("Session not found")

        history_result = await self.db.execute(
            select(ChatMessage)
            .where(ChatMessage.session_id == session_id)
            .order_by(ChatMessage.created_at)
        )
        history = history_result.scalars().all()

        user_msg = ChatMessage(session_id=session_id, role=MessageRole.USER, content=content)
        self.db.add(user_msg)

        user_result = await self.db.execute(select(User).where(User.id == user_id))
        user = user_result.scalar_one_or_none()

        messages = self._build_ai_messages(
            history, user_content=content,
            user_level=user.english_level.value if user else "intermediate",
        )

        try:
            ai_reply = await ai_client.chat(messages=messages, temperature=0.7)
        except Exception:
            ai_reply = (
                "I'm sorry, I'm having trouble connecting right now. "
                "Please try again in a moment! "
            )

        corrections = self._parse_corrections(ai_reply)
        clean_reply = self._clean_correction_markers(ai_reply)

        ai_msg = ChatMessage(
            session_id=session_id, role=MessageRole.ASSISTANT,
            content=clean_reply,
            grammar_corrections=corrections if corrections else None,
        )
        self.db.add(ai_msg)

        session.message_count = session.message_count + 2
        session.updated_at = datetime.utcnow()
        if session.message_count <= 2:
            session.title = content[:40] + ("..." if len(content) > 40 else "")

        await self.db.flush()
        await self.db.refresh(ai_msg)
        return ChatMessageResponse.model_validate(ai_msg)

    def _build_ai_messages(self, history, user_content, user_level):
        topic = "free conversation"
        if history:
            first = next((m for m in history if m.role == MessageRole.USER), None)
            if first:
                topic = first.content[:50]
        system_prompt = SPEAKING_COACH_PROMPT.format(level=user_level, topic=topic)
        messages = [{"role": "system", "content": system_prompt}]
        for msg in history:
            messages.append({"role": msg.role.value, "content": msg.content})
        messages.append({"role": "user", "content": user_content})
        return messages

    def _parse_corrections(self, text):
        pattern = r'\[Correction:\s*"([^"]+)"\s*->\s*"([^"]+)"\]'
        match = re.search(pattern, text)
        if match:
            note_pattern = r"\[Note:\s*(.+?)\]"
            note_match = re.search(note_pattern, text)
            return {
                "original": match.group(1),
                "corrected": match.group(2),
                "explanation": note_match.group(1) if note_match else "",
            }
        return None

    def _clean_correction_markers(self, text):
        text = re.sub(r'\[Correction:\s*"[^"]+"\s*->\s*"[^"]+"\]', "", text)
        text = re.sub(r"\[Note:\s*.+?\]", "", text)
        text = re.sub(r'\[More natural:\s*"([^"]+)"\]', r"\1", text)
        text = re.sub(r"\n{3,}", "\n\n", text).strip()
        return text
