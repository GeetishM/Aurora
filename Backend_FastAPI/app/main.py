from fastapi import FastAPI, WebSocket
from dotenv import load_dotenv
from .websocket import chat_socket

load_dotenv()

app = FastAPI(title="Aurora Backend")

@app.websocket("/ws/chat")
async def chat(ws: WebSocket):
    await chat_socket(ws)

@app.get("/")
def health():
    return {"status": "Aurora backend running"}
