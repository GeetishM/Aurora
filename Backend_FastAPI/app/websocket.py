from fastapi import WebSocket, WebSocketDisconnect
from .translate import translate_to_english, translate_from_english
from .router import route_query, is_hard_out_of_scope
from .rag import get_rag_answer_stream


async def chat_socket(ws: WebSocket):
    await ws.accept()
    history = []

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

            message = data.get("message")
            language = data.get("language", "en")

            if not message:
                await ws.send_json({"error": "Message cannot be empty"})
                continue

            # 1️⃣ Translate first
            user_en = translate_to_english(message, language)

            # 2️⃣ HARD BLOCK (regex, no LLM)
            if is_hard_out_of_scope(user_en):
                final = translate_from_english(
                    "I’m here to help with women’s health–related questions only. "
                    "I can’t assist with this topic.",
                    language
                )

                await ws.send_json({
                    "type": "final",
                    "text": final
                })
                continue

            history.append(f"user: {user_en}")

            # 3️⃣ Soft routing (LLM)
            category = route_query(user_en)

            # ---------- NON-STREAMING RESPONSES ----------
            if category == "out_of_scope":
                answer_en = (
                    "I’m here to help with women’s health–related questions only. "
                    "I can’t assist with this topic."
                )

                final = translate_from_english(answer_en, language)

                await ws.send_json({
                    "type": "final",
                    "text": final
                })

                history.append(f"assistant: {answer_en}")
                continue

            if category == "greeting":
                answer_en = "Hello. How can I support you today?"
                final = translate_from_english(answer_en, language)

                await ws.send_json({
                    "type": "final",
                    "text": final
                })

                history.append(f"assistant: {answer_en}")
                continue

            if category == "farewell":
                answer_en = "Take care. I’m here whenever you need support."
                final = translate_from_english(answer_en, language)

                await ws.send_json({
                    "type": "final",
                    "text": final
                })

                history.append(f"assistant: {answer_en}")
                continue

            # ---------- STREAMING RAG RESPONSE ----------
            full_answer = ""

            for token in get_rag_answer_stream(user_en, history):
                full_answer += token

                await ws.send_json({
                    "type": "chunk",
                    "text": token
                })

            # after streaming ends
            history.append(f"assistant: {full_answer}")

            final = translate_from_english(full_answer, language)

            await ws.send_json({
                "type": "final",
                "text": final
            })

    finally:
        await ws.close()
        print("WebSocket closed cleanly")
