# api/v1/speech.py - 语音转写 API（本地 Whisper / 云端兼容）

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, get_current_user_id
from app.services.transcription_service import transcribe

router = APIRouter(prefix="/speech", tags=["Speech"])


@router.post("/transcribe")
async def transcribe_audio(
    file: UploadFile = File(...),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """上传录音（m4a/wav/mp3），返回识别文本"""
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty audio file")
    if len(data) > 20 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Audio too large")
    try:
        text = await transcribe(data)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Transcription failed: {e}")
    return {"text": text}
