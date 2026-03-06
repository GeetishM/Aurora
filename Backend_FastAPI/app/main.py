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
    # "https://yourapp.com",
]

app = FastAPI(title="Aurora Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST"],   # ✅ POST needed for /translate
    allow_headers=["Content-Type"],
)


# ── WebSocket ─────────────────────────────────────────────────────────────────

@app.websocket("/ws/chat")
async def chat(ws: WebSocket):
    await chat_socket(ws)


# ── Translate endpoint ────────────────────────────────────────────────────────
# Called by Flutter when the user switches language — re-translates
# existing chat messages without going through the full RAG pipeline.

class TranslateRequest(BaseModel):
    text:     str
    language: str   # target language code e.g. "hi", "fr"

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