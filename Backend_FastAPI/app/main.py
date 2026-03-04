from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from .websocket import chat_socket

load_dotenv()

# ── Allowed origins (explicit, not wildcard) ───────────────────────
# Flutter web runs on port 8080 by default.
# Add more ports below if yours differs.
ALLOWED_ORIGINS = [
    "http://localhost",
    "http://localhost:8080",   # flutter web default
    "http://localhost:3000",
    "http://127.0.0.1:8080",
    # "https://yourapp.com",  # ← uncomment when you deploy
]

app = FastAPI(title="Aurora Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,  # ✅ explicit list, not "*"
    allow_credentials=False,         # ✅ no cookies/auth needed
    allow_methods=["GET"],           # ✅ only what we use
    allow_headers=["Content-Type"],
)

@app.websocket("/ws/chat")
async def chat(ws: WebSocket):
    await chat_socket(ws)

@app.get("/")
def health():
    return {"status": "Aurora backend running"}