from pydantic import BaseModel
from typing import List

class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    message: str
    language: str
    history: List[ChatMessage] = []

class ChatResponse(BaseModel):
    reply: str