import asyncio
from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
from .websocket import chat_socket
from .translate import translate_from_english

load_dotenv()

ALLOWED_ORIGINS = [
    "http://localhost",
    "http://localhost:8080",
    "http://localhost:3000",
    "http://127.0.0.1:8080",
]

app = FastAPI(title="Aurora Backend")

# ✅ Import AFTER app is created — fixes NameError
from app.routers.transcribe import router as transcribe_router
app.include_router(transcribe_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)


# ── WebSocket ─────────────────────────────────────────────────────────────────

@app.websocket("/ws/chat")
async def chat(ws: WebSocket):
    await chat_socket(ws)


# ── Translate endpoint ────────────────────────────────────────────────────────

class TranslateRequest(BaseModel):
    text:     str
    language: str

class TranslateResponse(BaseModel):
    translated: str

@app.post("/translate", response_model=TranslateResponse)
async def translate(req: TranslateRequest):
    result = await asyncio.to_thread(
        translate_from_english, req.text, req.language
    )
    return TranslateResponse(translated=result)


# ── Health ────────────────────────────────────────────────────────────────────

@app.get("/")
def health():
    return {"status": "Aurora backend running"}