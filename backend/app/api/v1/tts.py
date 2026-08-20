# api/v1/tts.py - 云端语音合成 API（Edge TTS，不依赖手机 TTS 引擎）

import hashlib
import os
import time

import edge_tts
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import Response

from app.core.dependencies import get_current_user_id

router = APIRouter(prefix="/tts", tags=["TTS"])

# 允许的语音
SUPPORTED_VOICES = {
    "en-US-AriaNeural",
    "en-US-JennyNeural",
    "en-US-GuyNeural",
    "zh-CN-XiaoxiaoNeural",
}

# 简单内存缓存：sha1(voice:text) -> (过期时间戳, 音频字节)
_CACHE: dict[str, tuple[float, bytes]] = {}
_CACHE_TTL_SECONDS = 86400  # 缓存 24 小时，重复朗读秒回
_DISK_CACHE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "tts_cache")
_DISK_CACHE_DIR = os.path.normpath(_DISK_CACHE_DIR)


def _disk_path(key: str) -> str:
    return os.path.join(_DISK_CACHE_DIR, f"{key}.mp3")


@router.get("")
async def synthesize(
    text: str = Query(..., min_length=1, max_length=500, description="要朗读的文本"),
    voice: str = Query("en-US-AriaNeural", description="语音角色"),
    _user_id: str = Depends(get_current_user_id),
):
    """合成文本为 MP3 音频（Edge TTS）"""
    if voice not in SUPPORTED_VOICES:
        raise HTTPException(status_code=400, detail=f"Unsupported voice: {voice}")

    key = hashlib.sha1(f"{voice}:{text}".encode("utf-8")).hexdigest()
    cached = _CACHE.get(key)
    if cached and cached[0] > time.time():
        return Response(content=cached[1], media_type="audio/mpeg")
    # 磁盘缓存（后端重启后仍秒回）
    path = _disk_path(key)
    if os.path.exists(path):
        try:
            with open(path, "rb") as f:
                audio = f.read()
            _CACHE[key] = (time.time() + _CACHE_TTL_SECONDS, audio)
            return Response(content=audio, media_type="audio/mpeg")
        except OSError:
            pass

    try:
        communicate = edge_tts.Communicate(text, voice=voice)
        chunks = []
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                chunks.append(chunk["data"])
        audio = b"".join(chunks)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"TTS service error: {e}")

    if not audio:
        raise HTTPException(status_code=502, detail="TTS synthesis returned no audio")

    _CACHE[key] = (time.time() + _CACHE_TTL_SECONDS, audio)
    try:
        os.makedirs(_DISK_CACHE_DIR, exist_ok=True)
        with open(path, "wb") as f:
            f.write(audio)
    except OSError as e:
        print(f"TTS disk cache write error: {e}")
    if len(_CACHE) > 200:
        now = time.time()
        for k in [k for k, v in _CACHE.items() if v[0] < now]:
            _CACHE.pop(k, None)
    return Response(content=audio, media_type="audio/mpeg")
