import asyncio
import socket
from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
from .websocket import chat_socket
from .translate import translate_from_english

load_dotenv()

app = FastAPI(title="Aurora Backend")

# ✅ Import AFTER app is created
from app.routers.transcribe import router as transcribe_router

app.include_router(transcribe_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def print_local_ip():
    try:
        hostname = socket.gethostname()
        local_ip = socket.gethostbyname(hostname)
    except Exception:
        local_ip = "unknown"
    


@app.websocket("/ws/chat")
async def chat(ws: WebSocket):
    await chat_socket(ws)


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


@app.get("/")
def health():
    return {"status": "Aurora backend running"}