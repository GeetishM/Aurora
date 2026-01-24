# FastAPI entry point

from fastapi import FastAPI
from app.schemas import ChatRequest, ChatResponse
from app.translate import to_english, from_english
from app.router import route_query
from app.rag import get_rag_answer

app = FastAPI(title="Aurora Women’s Healthcare API")

@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    user_en = to_english(req.message, req.language)

    history_en = [
        {"role": m.role, "content": m.content}
        for m in req.history
    ]

    category = route_query(user_en)

    if category == "greeting":
        answer_en = "Hello. How can I support you today?"

    elif category == "out_of_scope":
        answer_en = (
            "I focus specifically on women’s healthcare topics."
        )

    else:
        answer_en = get_rag_answer(user_en, history_en)

    final_answer = from_english(answer_en, req.language)

    updated_history = req.history + [
        {"role": "user", "content": user_en},
        {"role": "assistant", "content": answer_en},
    ]

    return ChatResponse(
        reply=final_answer,
        history=updated_history
    )
