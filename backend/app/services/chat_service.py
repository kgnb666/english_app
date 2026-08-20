# services/chat_service.py - AI 对话服务 + 动态主题 + 结构化纠错

import json
import re
import time
from datetime import datetime
from typing import AsyncGenerator, Optional
from sqlalchemy import select, desc, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.chat import ChatSession, ChatMessage, MessageRole
from app.models.user import User
from app.ai.client import ai_client
from app.ai.prompts import (
    SPEAKING_COACH_PROMPT,
    SPEAKING_COACH_PROMPT_STREAM,
    SESSION_SUMMARY_PROMPT,
)
from app.schemas.chat import ChatMessageResponse, ChatSessionResponse, ChatSessionDetailResponse
from app.services.profile_service import ProfileService, ERROR_TYPE_CN

# 基于用户等级的动态主题池
TOPICS_BY_LEVEL = {
    "beginner": ["Daily conversation", "Introduce yourself", "Talking about hobbies", "Ordering food", "Asking for directions"],
    "elementary": ["Weekend plans", "Favorite movies", "Travel experiences", "Shopping conversations", "Making friends"],
    "intermediate": ["Technology and life", "Cultural differences", "Work-life balance", "Environmental issues", "Social media pros and cons"],
    "upper_intermediate": ["Business discussion", "Current events", "Career development", "Financial literacy", "Science and future"],
    "advanced": ["Debate topics", "Philosophical questions", "Global economy", "Artificial intelligence ethics", "Literature discussion"],
}

# 上下文窗口：最多携带最近 20 条历史消息，单条超长截断
MAX_HISTORY_MESSAGES = 20
MAX_MESSAGE_CHARS = 2000
CORRECTIONS_MARKER = "###CORRECTIONS###"


class AIServiceError(Exception):
    """AI 服务调用失败（可重试），不污染会话上下文"""


class ChatService:

    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_session(self, user_id: str, topic: Optional[str] = None) -> ChatSessionResponse:
        title = topic or "Free Talk"
        session = ChatSession(user_id=user_id, title=title, topic=topic, message_count=0)
        self.db.add(session)
        await self.db.flush()
        await self.db.refresh(session)
        return ChatSessionResponse.model_validate(session)

    async def list_sessions(self, user_id: str) -> list[ChatSessionResponse]:
        result = await self.db.execute(select(ChatSession).where(ChatSession.user_id == user_id).order_by(desc(ChatSession.updated_at)))
        return [ChatSessionResponse.model_validate(s) for s in result.scalars().all()]

    async def get_session_detail(self, session_id: str, user_id: str) -> ChatSessionDetailResponse:
        result = await self.db.execute(select(ChatSession).where(ChatSession.id == session_id, ChatSession.user_id == user_id))
        session = result.scalar_one_or_none()
        if not session: raise ValueError("Session not found")
        msg_result = await self.db.execute(select(ChatMessage).where(ChatMessage.session_id == session_id).order_by(ChatMessage.created_at))
        messages = msg_result.scalars().all()
        return ChatSessionDetailResponse(
            id=session.id,
            title=session.title,
            topic=session.topic,
            messages=[self._to_response(m) for m in messages],
            created_at=session.created_at,
            updated_at=session.updated_at,
        )

    async def delete_session(self, session_id: str, user_id: str):
        result = await self.db.execute(select(ChatSession).where(ChatSession.id == session_id, ChatSession.user_id == user_id))
        session = result.scalar_one_or_none()
        if not session: raise ValueError("Session not found")
        await self.db.execute(delete(ChatMessage).where(ChatMessage.session_id == session_id))
        await self.db.flush(); await self.db.delete(session); await self.db.flush()

    async def send_message(self, session_id: str, user_id: str, content: str) -> ChatMessageResponse:
        started = time.time()
        result = await self.db.execute(select(ChatSession).where(ChatSession.id == session_id, ChatSession.user_id == user_id))
        session = result.scalar_one_or_none()
        if not session: raise ValueError("Session not found")
        hist_result = await self.db.execute(select(ChatMessage).where(ChatMessage.session_id == session_id).order_by(ChatMessage.created_at))
        history = hist_result.scalars().all()
        user_msg = ChatMessage(session_id=session_id, role=MessageRole.USER, content=content)
        self.db.add(user_msg)
        # 先保存用户消息：即使 AI 失败也不丢失用户发言
        await self.db.flush()

        # 用户画像上下文：等级、目标、常犯错误、近期学习记录
        profile_svc = ProfileService(self.db)
        context = await profile_svc.build_ai_context(user_id)
        messages = self._build_ai_messages(history, content, context)

        usage = {}
        ai_model = ""
        try:
            result = await ai_client.chat(
                messages=messages, temperature=0.7, json_mode=True, return_usage=True
            )
            ai_reply = result["content"] if isinstance(result, dict) else result
            usage = result.get("usage", {}) if isinstance(result, dict) else {}
            ai_model = result.get("model", "") if isinstance(result, dict) else ""
        except Exception:
            # AI 调用失败：抛出可重试错误，不写入任何 AI 消息
            raise AIServiceError()

        parsed = self._parse_json_reply(ai_reply)
        if parsed is None:
            # 格式异常：直接用 AI 原文回复（清理标记），不再二次调用 AI
            reply_text = self._clean_correction_markers(ai_reply)
            legacy = self._parse_corrections(ai_reply)
            corrections = [legacy] if legacy else []
        else:
            reply_text = parsed.get("reply") or ""
            corrections = parsed.get("corrections") or []

        if not reply_text.strip():
            raise AIServiceError()

        # 规范化纠错结构，并写入错误记录（供 AI 后续针对性训练）
        normalized = self._normalize_corrections(corrections)
        if normalized:
            await profile_svc.record_corrections(user_id, normalized)
        grammar_data = {"corrections": normalized} if normalized else None

        metadata = {
            "latency_ms": int((time.time() - started) * 1000),
            "model": ai_model,
        }
        if usage:
            metadata["token_usage"] = usage

        ai_msg = ChatMessage(
            session_id=session_id,
            role=MessageRole.ASSISTANT,
            content=reply_text,
            grammar_corrections=grammar_data,
        )
        self.db.add(ai_msg)
        session.message_count = (session.message_count or 0) + 2; session.updated_at = datetime.utcnow()
        # 仅默认标题才用首条消息覆盖，保留用户选择的话题标题
        if session.message_count <= 2 and session.title in (None, "", "Free Talk"):
            session.title = content[:40] + ("..." if len(content) > 40 else "")
        # Auto-record stats
        from app.services.stats_service import StatsService
        ss = StatsService(self.db); await ss.record_activity(user_id, "chat", 1)
        await self.db.flush(); await self.db.refresh(ai_msg)
        return self._to_response(ai_msg, metadata=metadata)

    @staticmethod
    def _to_response(msg: ChatMessage, metadata: Optional[dict] = None) -> ChatMessageResponse:
        """手动构造响应，避免 ORM 的 metadata 属性与响应字段冲突"""
        return ChatMessageResponse(
            id=msg.id,
            session_id=msg.session_id,
            role=msg.role.value,
            content=msg.content,
            grammar_corrections=msg.grammar_corrections,
            metadata=metadata,
            created_at=msg.created_at,
        )

    async def stream_message(
        self, session_id: str, user_id: str, content: str
    ) -> AsyncGenerator[dict, None]:
        """流式对话：逐 token 产出 reply，结束时产出 done（含纠错与 metadata）。
        事件类型：chunk / corrections / done / error
        """
        hist_result = await self.db.execute(select(ChatMessage).where(ChatMessage.session_id == session_id).order_by(ChatMessage.created_at))
        history = hist_result.scalars().all()
        user_msg = ChatMessage(session_id=session_id, role=MessageRole.USER, content=content)
        self.db.add(user_msg)
        await self.db.flush()

        profile_svc = ProfileService(self.db)
        context = await profile_svc.build_ai_context(user_id)
        messages = self._build_ai_messages(history, content, context, stream_mode=True)

        reply_parts = []
        corrections_raw = []
        buffer = ""
        in_corrections = False
        started = time.time()

        try:
            async for delta in ai_client.stream(messages=messages, temperature=0.7):
                if in_corrections:
                    corrections_raw.append(delta)
                    continue
                buffer += delta
                # 按行聚合，marker 独占一行，不受流式分块影响
                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    idx = line.find(CORRECTIONS_MARKER)
                    if idx >= 0:
                        reply_parts.append(line[:idx])
                        if line[:idx]:
                            yield {"type": "chunk", "text": line[:idx]}
                        tail = line[idx + len(CORRECTIONS_MARKER):]
                        if tail.strip():
                            corrections_raw.append(tail)
                        in_corrections = True
                        break
                    if line:
                        reply_parts.append(line)
                        yield {"type": "chunk", "text": line}
        except Exception:
            yield {"type": "error", "message": "ai_unavailable", "retryable": True}
            return

        if buffer and not in_corrections:
            idx = buffer.find(CORRECTIONS_MARKER)
            if idx >= 0:
                reply_parts.append(buffer[:idx])
                if buffer[:idx]:
                    yield {"type": "chunk", "text": buffer[:idx]}
                tail = buffer[idx + len(CORRECTIONS_MARKER):]
                if tail.strip():
                    corrections_raw.append(tail)
                in_corrections = True
            else:
                reply_parts.append(buffer)
                yield {"type": "chunk", "text": buffer}
        elif buffer and in_corrections:
            corrections_raw.append(buffer)

        reply_text = "".join(reply_parts).strip()
        if not reply_text:
            yield {"type": "error", "message": "ai_unavailable", "retryable": True}
            return

        corrections = []
        if corrections_raw:
            raw = "".join(corrections_raw).strip()
            parsed = self._parse_json_array(raw)
            if parsed is not None:
                corrections = parsed
        normalized = self._normalize_corrections(corrections)
        if normalized:
            await profile_svc.record_corrections(user_id, normalized)
        grammar_data = {"corrections": normalized} if normalized else None
        yield {"type": "corrections", "data": grammar_data}

        metadata = {
            "latency_ms": int((time.time() - started) * 1000),
            "streamed": True,
        }
        ai_msg = ChatMessage(
            session_id=session_id,
            role=MessageRole.ASSISTANT,
            content=reply_text,
            grammar_corrections=grammar_data,
        )
        self.db.add(ai_msg)
        session = (await self.db.execute(
            select(ChatSession).where(ChatSession.id == session_id, ChatSession.user_id == user_id)
        )).scalar_one_or_none()
        if session:
            session.message_count = (session.message_count or 0) + 2
            session.updated_at = datetime.utcnow()
            if session.message_count <= 2 and session.title in (None, "", "Free Talk"):
                session.title = content[:40] + ("..." if len(content) > 40 else "")
        from app.services.stats_service import StatsService
        await StatsService(self.db).record_activity(user_id, "chat", 1)
        await self.db.flush()
        await self.db.refresh(ai_msg)

        resp = self._to_response(ai_msg, metadata=metadata)
        yield {"type": "done", "data": resp.model_dump(mode="json")}

    async def generate_summary(self, session_id: str, user_id: str) -> dict:
        """AI 生成会话总结：主题、要点、待改进项"""
        r = await self.db.execute(select(ChatSession).where(
            ChatSession.id == session_id, ChatSession.user_id == user_id
        ))
        if not r.scalar_one_or_none():
            raise ValueError("Session not found")
        msg_result = await self.db.execute(
            select(ChatMessage).where(ChatMessage.session_id == session_id).order_by(ChatMessage.created_at)
        )
        messages = list(msg_result.scalars().all())
        if not messages:
            raise ValueError("No messages")
        conversation = "\n".join(
            f"{'User' if m.role == MessageRole.USER else 'AI'}: {m.content[:300]}"
            for m in messages[-30:]
        )
        prompt = SESSION_SUMMARY_PROMPT.format(conversation=conversation)
        try:
            reply = await ai_client.chat(
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=800,
                json_mode=True,
            )
            parsed = self._parse_json_reply(reply)
            if parsed:
                return {
                    "summary_cn": str(parsed.get("summary_cn") or ""),
                    "key_points": [str(x) for x in parsed.get("key_points") or []],
                    "to_improve": [str(x) for x in parsed.get("to_improve") or []],
                }
        except Exception:
            pass
        raise AIServiceError()

    async def get_recommended_topics(self, user_id: str) -> list[str]:
        """根据用户等级动态推荐聊天主题"""
        r = await self.db.execute(select(User).where(User.id == user_id))
        user = r.scalar_one_or_none()
        level = user.english_level.value if user else "beginner"
        return TOPICS_BY_LEVEL.get(level, TOPICS_BY_LEVEL["beginner"])

    def _build_ai_messages(self, history, user_content, context: dict, stream_mode: bool = False) -> list[dict]:
        topic = "free conversation"
        # 窗口化：只保留最近 N 条历史，控制 token 消耗
        window = list(history)[-MAX_HISTORY_MESSAGES:]
        first_user = next((m for m in window if m.role == MessageRole.USER), None)
        if first_user:
            topic = first_user.content[:50]
        common_errors = context.get("common_errors") or []
        errors_text = "none yet" if not common_errors else "; ".join(
            f"{e.get('type', '')} x{e.get('count', 0)}" for e in common_errors
        )
        # 会话内即时纠错：最近 3 条纠错（wrong -> correct）注入，提醒重复错误
        recent_corrections = []
        for msg in reversed(window):
            if msg.role == MessageRole.ASSISTANT and msg.grammar_corrections:
                for c in (msg.grammar_corrections or {}).get("corrections") or []:
                    wrong = c.get("wrong")
                    correct = c.get("correct")
                    if wrong and correct:
                        recent_corrections.append(f"{wrong} -> {correct}")
                    if len(recent_corrections) >= 3:
                        break
            if len(recent_corrections) >= 3:
                break
        if recent_corrections:
            errors_text += " | recent corrections this session: " + "; ".join(recent_corrections)
        recent = context.get("recent_study") or {}
        recent_text = (
            f"{recent.get('study_minutes', 0)} min study, "
            f"{recent.get('words_learned', 0)} new words, "
            f"{recent.get('words_reviewed', 0)} reviews, "
            f"{recent.get('reading_count', 0)} readings, "
            f"{recent.get('writing_count', 0)} essays"
        )
        prefs = context.get("preferences") or {}
        prefs_text = json.dumps(prefs, ensure_ascii=False) if prefs else "none"
        template = SPEAKING_COACH_PROMPT_STREAM if stream_mode else SPEAKING_COACH_PROMPT
        system_prompt = template.format(
            level=context.get("level", "beginner"),
            goal=context.get("goal", "Improve overall English"),
            vocabulary_size=context.get("vocabulary_size", 0),
            common_errors=errors_text,
            recent_study=recent_text,
            preferences=prefs_text,
            topic=topic,
        )
        msgs = [{"role": "system", "content": system_prompt}]
        for msg in window:
            content = msg.content
            if len(content) > MAX_MESSAGE_CHARS:
                content = content[:MAX_MESSAGE_CHARS] + " ..."
            msgs.append({"role": msg.role.value, "content": content})
        msgs.append({"role": "user", "content": user_content})
        return msgs

    # ===== 结构化纠错解析 =====

    @staticmethod
    def _parse_json_reply(text: str) -> Optional[dict]:
        """从 AI 回复中提取 JSON（兼容代码块包裹）"""
        if not text:
            return None
        cleaned = text.strip()
        if cleaned.startswith("```"):
            cleaned = re.sub(r"^```[a-zA-Z]*\n?", "", cleaned)
            cleaned = re.sub(r"\n?```$", "", cleaned)
        try:
            data = json.loads(cleaned)
            return data if isinstance(data, dict) else None
        except json.JSONDecodeError:
            pass
        m = re.search(r"\{.*\}", cleaned, re.DOTALL)
        if m:
            try:
                data = json.loads(m.group())
                return data if isinstance(data, dict) else None
            except json.JSONDecodeError:
                return None
        return None

    @staticmethod
    def _parse_json_array(text: str) -> Optional[list]:
        """解析纠错 JSON 数组（兼容代码块包裹）"""
        if not text:
            return None
        cleaned = text.strip()
        if cleaned.startswith("```"):
            cleaned = re.sub(r"^```[a-zA-Z]*\n?", "", cleaned)
            cleaned = re.sub(r"\n?```$", "", cleaned)
        try:
            data = json.loads(cleaned)
            return data if isinstance(data, list) else None
        except json.JSONDecodeError:
            pass
        m = re.search(r"\[.*\]", cleaned, re.DOTALL)
        if m:
            try:
                data = json.loads(m.group())
                return data if isinstance(data, list) else None
            except json.JSONDecodeError:
                return None
        return None

    @staticmethod
    def _normalize_corrections(corrections: list) -> list[dict]:
        """统一纠错字段为 wrong/correct/reason/better_expression/error_type"""
        result = []
        for c in corrections:
            if not isinstance(c, dict):
                continue
            wrong = (c.get("wrong") or c.get("original") or "").strip()
            correct = (c.get("correct") or c.get("corrected") or "").strip()
            if not wrong or not correct:
                continue
            raw_type = str(c.get("error_type") or "")
            error_type = ProfileService._normalize_error_type(raw_type, wrong)
            result.append({
                "wrong": wrong,
                "correct": correct,
                "reason": str(c.get("reason") or c.get("explanation") or "").strip(),
                "better_expression": str(c.get("better_expression") or "").strip(),
                "error_type": error_type,
                "error_type_cn": ERROR_TYPE_CN.get(error_type, "其他错误"),
            })
        return result

    def _parse_corrections(self, text: str) -> Optional[dict]:
        """兼容旧格式：[Correction: "..." -> "..."] + [Note: ...]"""
        pattern = r'\[Correction:\s*"([^"]+)"\s*->\s*"([^"]+)"\]'
        match = re.search(pattern, text)
        if match:
            note_pattern = r"\[Note:\s*(.+?)\]"
            note_match = re.search(note_pattern, text)
            return {
                "wrong": match.group(1),
                "correct": match.group(2),
                "reason": note_match.group(1) if note_match else "",
                "better_expression": "",
                "error_type": "",
            }
        return None

    def _clean_correction_markers(self, text: str) -> str:
        text = re.sub(r'\[Correction:\s*"[^"]+"\s*->\s*"[^"]+"\]', "", text)
        text = re.sub(r"\[Note:\s*.+?\]", "", text)
        text = re.sub(r'\[More natural:\s*"([^"]+)"\]', r"\1", text)
        return re.sub(r"\n{3,}", "\n\n", text).strip()
