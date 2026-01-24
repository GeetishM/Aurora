# Pydantic models for request and response schemas
from pydantic import BaseModel
from typing import List, Dict

class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    message: str
    language: str = "en"
    history: List[ChatMessage]

class ChatResponse(BaseModel):
    reply: str
    history: List[ChatMessage]
