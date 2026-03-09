import asyncio
import threading
import logging
from fastapi import WebSocket, WebSocketDisconnect

from .translate   import translate_to_english, translate_from_english
from .router      import route_query, is_hard_out_of_scope
from .rag         import get_rag_answer_stream, maybe_summarise_history
from .response_banks import (
    random_greeting, random_farewell,
    random_out_of_scope, RATE_LIMITED,
)

logger = logging.getLogger(__name__)


# ── Streaming helper ──────────────────────────────────────────────────────────

async def _stream_rag(query: str, history: list[str], ws: WebSocket):
    """
    Runs the synchronous RAG generator in a background thread.
    Sends each token as a 'chunk' JSON frame.
    Returns (full_answer: str, sources: list) when done.
    """
    loop  = asyncio.get_event_loop()
    queue: asyncio.Queue = asyncio.Queue()

    def _run():
        try:
            for token, sources in get_rag_answer_stream(query, history):
                loop.call_soon_threadsafe(queue.put_nowait, (token, sources))
        except Exception as e:
            logger.exception("RAG thread error: %s", e)
        finally:
            loop.call_soon_threadsafe(queue.put_nowait, None)  # sentinel

    threading.Thread(target=_run, daemon=True).start()

    full_answer = ""
    sources     = []

    while True:
        item = await queue.get()
        if item is None:
            break

        token, item_sources = item

        if item_sources is not None:
            # Final yield — carries sources, token is ""
            sources = item_sources
        else:
            full_answer += token
            await ws.send_json({"type": "chunk", "text": token})

    return full_answer, sources


# ── Main socket handler ───────────────────────────────────────────────────────

async def chat_socket(ws: WebSocket):
    await ws.accept()
    logger.info("WebSocket accepted")

    # Per-connection state
    history:       list[str] = []
    tx_cache:      dict      = {}   # translation cache for this session
    has_interacted: bool     = False

    try:
        while True:
            # ── Receive ───────────────────────────────────────────────────────
            try:
                data = await ws.receive_json()
            except WebSocketDisconnect:
                logger.info("Client disconnected")
                break
            except Exception:
                await ws.send_json({"error": "Invalid message format"})
                continue

            message:  str = data.get("message", "").strip()
            language: str = data.get("language", "en")

            if not message:
                await ws.send_json({"error": "Message cannot be empty"})
                continue

            # Input length guard
            if len(message) > 1000:
                await ws.send_json({"error": "Message too long (max 1000 characters)"})
                continue

            # ── 1. Translate to English ───────────────────────────────────────
            user_en = await asyncio.to_thread(
                translate_to_english, message, language, tx_cache
            )

            if user_en is None:
                # Rate limited during translation
                final = await asyncio.to_thread(
                    translate_from_english, RATE_LIMITED, language, tx_cache
                )
                await ws.send_json({"type": "final", "text": final})
                continue

            # ── 2. Hard block (regex) ─────────────────────────────────────────
            if is_hard_out_of_scope(user_en):
                answer_en = random_out_of_scope()
                final = await asyncio.to_thread(
                    translate_from_english, answer_en, language, tx_cache
                )
                await ws.send_json({"type": "final", "text": final})
                continue

            history.append(f"user: {user_en}")

            # ── 3. Soft routing (LLM) ─────────────────────────────────────────
            category = await asyncio.to_thread(route_query, user_en)

            # ── 4. Non-streaming responses ────────────────────────────────────
            if category == "rate_limited":
                final = await asyncio.to_thread(
                    translate_from_english, RATE_LIMITED, language, tx_cache
                )
                await ws.send_json({"type": "final", "text": final})
                continue

            if category == "greeting":
                answer_en = random_greeting(returning=has_interacted)
                final = await asyncio.to_thread(
                    translate_from_english, answer_en, language, tx_cache
                )
                await ws.send_json({"type": "final", "text": final})
                history.append(f"assistant: {answer_en}")
                has_interacted = True
                continue

            if category == "farewell":
                answer_en = random_farewell()
                final = await asyncio.to_thread(
                    translate_from_english, answer_en, language, tx_cache
                )
                await ws.send_json({"type": "final", "text": final})
                history.append(f"assistant: {answer_en}")
                continue

            if category == "out_of_scope":
                answer_en = random_out_of_scope()
                final = await asyncio.to_thread(
                    translate_from_english, answer_en, language, tx_cache
                )
                await ws.send_json({"type": "final", "text": final})
                history.append(f"assistant: {answer_en}")
                continue

            # ── 5. Streaming RAG response ─────────────────────────────────────
            full_answer, sources = await _stream_rag(user_en, history, ws)

            history.append(f"assistant: {full_answer}")
            has_interacted = True

            # Translate the full answer if needed, then send final frame
            final = await asyncio.to_thread(
                translate_from_english, full_answer, language, tx_cache
            )

            await ws.send_json({
                "type":    "final",
                "text":    final,
                "sources": sources,   # Flutter can optionally display these
            })

            # ── 6. Summarise history if it's grown too long ───────────────────
            history = await asyncio.to_thread(maybe_summarise_history, history)

    finally:
        try:
            await ws.close()
            logger.info("WebSocket closed cleanly")
        except RuntimeError:
            logger.info("WebSocket already closed")