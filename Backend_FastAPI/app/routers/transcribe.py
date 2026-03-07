"""
app/routers/transcribe.py
─────────────────────────
POST /api/transcribe
  • Accepts an audio file (m4a / webm / wav / mp3 / ogg)
  • Transcribes it with Groq Whisper (whisper-large-v3-turbo)
  • Returns { "text": "...", "language": "..." }

Add to app/main.py:
    from app.routers.transcribe import router as transcribe_router
    app.include_router(transcribe_router)
"""

import os
import tempfile
from fastapi import APIRouter, File, HTTPException, UploadFile
from groq import Groq

router = APIRouter()

# Re-use the same Groq client that the rest of the app uses.
# GROQ_API_KEY must be set in your .env / environment.
_groq = Groq(api_key=os.getenv("GROQ_API_KEY"))

# Allowed audio MIME types → file extension
_ALLOWED: dict[str, str] = {
    "audio/m4a":       ".m4a",
    "audio/x-m4a":     ".m4a",
    "audio/mp4":       ".m4a",
    "audio/mpeg":      ".mp3",
    "audio/mp3":       ".mp3",
    "audio/wav":       ".wav",
    "audio/x-wav":     ".wav",
    "audio/webm":      ".webm",
    "audio/ogg":       ".ogg",
    "application/octet-stream": ".m4a",   # Flutter record default
}


@router.post("/api/transcribe")
async def transcribe_audio(file: UploadFile = File(...)):
    """
    Transcribe an audio recording using Groq Whisper.

    Flutter sends a multipart POST with field name 'file'.
    Returns JSON: { "text": "transcribed text", "language": "detected lang" }
    """
    # ── Validate content type ──────────────────────────────────────────────
    content_type = (file.content_type or "application/octet-stream").lower()
    ext = _ALLOWED.get(content_type)
    if ext is None:
        # Try to infer from filename
        if file.filename:
            fn_ext = os.path.splitext(file.filename)[1].lower()
            if fn_ext in {".m4a", ".mp3", ".wav", ".webm", ".ogg", ".mp4"}:
                ext = fn_ext
        if ext is None:
            raise HTTPException(
                status_code=415,
                detail=f"Unsupported audio format: {content_type}",
            )

    # ── Write to temp file (Groq SDK needs a real file path) ──────────────
    audio_bytes = await file.read()
    if len(audio_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty audio file.")

    tmp_path: str | None = None
    try:
        with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as tmp:
            tmp.write(audio_bytes)
            tmp_path = tmp.name

        # ── Groq Whisper transcription ─────────────────────────────────
        with open(tmp_path, "rb") as audio_file:
            result = _groq.audio.transcriptions.create(
                model="whisper-large-v3-turbo",   # fast + multilingual
                file=audio_file,
                response_format="verbose_json",    # includes language field
            )

        return {
            "text":     result.text.strip(),
            "language": getattr(result, "language", "unknown"),
        }

    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Transcription failed: {str(exc)}",
        ) from exc

    finally:
        # Always clean up the temp file
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except OSError:
                pass