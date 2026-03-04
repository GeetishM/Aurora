import asyncio
import threading
from fastapi import WebSocket, WebSocketDisconnect
from .translate import translate_to_english, translate_from_english
from .router import route_query, is_hard_out_of_scope
from .rag import get_rag_answer_stream


async def _stream_rag_to_socket(query: str, history: list, ws: WebSocket) -> str:
    """
    Runs the synchronous RAG streaming generator in a background thread and
    forwards each token to the WebSocket without blocking the event loop.
    Returns the full assembled answer.
    """
    loop = asyncio.get_event_loop()
    queue: asyncio.Queue = asyncio.Queue()

    def _run():
        try:
            for token in get_rag_answer_stream(query, history):
                loop.call_soon_threadsafe(queue.put_nowait, token)
        finally:
            loop.call_soon_threadsafe(queue.put_nowait, None)   # sentinel

    thread = threading.Thread(target=_run, daemon=True)
    thread.start()

    full_answer = ""
    while True:
        token = await queue.get()
        if token is None:
            break
        full_answer += token
        await ws.send_json({"type": "chunk", "text": token})

    return full_answer


async def chat_socket(ws: WebSocket):
    await ws.accept()
    print("Socket accepted")
    history: list[str] = []

    try:
        while True:
            try:
                data = await ws.receive_json()
            except WebSocketDisconnect:
                print("WebSocket disconnected by client")
                break
            except Exception:
                await ws.send_json({"error": "Invalid message format"})
                continue

            message: str = data.get("message", "").strip()
            language: str = data.get("language", "en")

            if not message:
                await ws.send_json({"error": "Message cannot be empty"})
                continue

            # 1️⃣  Translate input to English (runs in thread to avoid blocking)
            user_en = await asyncio.to_thread(translate_to_english, message, language)

            # 2️⃣  Hard block — regex, no LLM call needed
            if is_hard_out_of_scope(user_en):
                final = await asyncio.to_thread(
                    translate_from_english,
                    "I'm here to help with women's health–related questions only. "
                    "I can't assist with this topic.",
                    language,
                )
                await ws.send_json({"type": "final", "text": final})
                continue

            history.append(f"user: {user_en}")

            # 3️⃣  Soft routing via LLM
            category = await asyncio.to_thread(route_query, user_en)

            # ---------- NON-STREAMING RESPONSES ----------
            simple_replies = {
                "out_of_scope": (
                    "I'm here to help with women's health–related questions only. "
                    "I can't assist with this topic."
                ),
                "greeting": "Hello! How can I support you today?",
                "farewell": "Take care. I'm here whenever you need support.",
            }

            if category in simple_replies:
                answer_en = simple_replies[category]
                final = await asyncio.to_thread(translate_from_english, answer_en, language)
                await ws.send_json({"type": "final", "text": final})
                history.append(f"assistant: {answer_en}")
                continue

            # ---------- STREAMING RAG RESPONSE ----------
            # Chunks are sent in English as they arrive; a translated
            # "final" message is sent at the end so the frontend can
            # replace the streamed text with the user's language.
            full_answer = await _stream_rag_to_socket(user_en, history, ws)

            history.append(f"assistant: {full_answer}")

            final = await asyncio.to_thread(translate_from_english, full_answer, language)
            await ws.send_json({"type": "final", "text": final})

    finally:
        await ws.close()
        print("WebSocket closed cleanly")