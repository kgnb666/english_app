# services/transcription_service.py - 语音转写服务（本地 faster-whisper / 云端兼容 API）

import asyncio
import os
import tempfile

import httpx
from faster_whisper import WhisperModel

from app.core.config import settings

_model = None
_model_lock = asyncio.Lock()


async def _get_model() -> WhisperModel:
    """惰性加载本地 Whisper 模型（CPU + int8，首次加载约 0.5 秒）"""
    global _model
    if _model is None:
        async with _model_lock:
            if _model is None:
                _model = await asyncio.to_thread(
                    WhisperModel, settings.WHISPER_MODEL, device="cpu", compute_type="int8"
                )
    return _model


async def transcribe(audio_bytes: bytes) -> str:
    """按配置选择本地或云端转写，返回识别文本"""
    if not audio_bytes:
        return ""
    if settings.WHISPER_PROVIDER == "local":
        return await _transcribe_local(audio_bytes)
    return await _transcribe_api(audio_bytes)


async def _transcribe_local(audio_bytes: bytes) -> str:
    model = await _get_model()
    suffix = ".m4a"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as f:
        f.write(audio_bytes)
        tmp = f.name
    try:
        segments, _info = await asyncio.to_thread(
            model.transcribe, tmp, language="en", beam_size=1
        )
        return "".join(s.text for s in segments).strip()
    finally:
        try:
            os.remove(tmp)
        except OSError:
            pass


async def _transcribe_api(audio_bytes: bytes) -> str:
    """OpenAI 兼容转写（SiliconFlow / OpenAI），配置一键切换"""
    if not settings.WHISPER_API_KEY:
        raise RuntimeError("WHISPER_API_KEY is not configured")
    async with httpx.AsyncClient(timeout=60.0) as client:
        resp = await client.post(
            f"{settings.WHISPER_BASE_URL}/audio/transcriptions",
            headers={"Authorization": f"Bearer {settings.WHISPER_API_KEY}"},
            files={"file": ("voice.m4a", audio_bytes, "audio/mp4")},
            data={"model": settings.WHISPER_MODEL_NAME, "language": "en"},
        )
        resp.raise_for_status()
        return str(resp.json().get("text") or "").strip()
