from fastapi import WebSocket, WebSocketDisconnect
from .translate import translate_to_english, translate_from_english
from .router import route_query
from .rag import get_rag_answer
from .router import route_query, is_hard_out_of_scope


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
                await ws.send_json({
                    "type": "final",
                    "text": (
                        "I’m here to help with women’s health–related questions only. "
                        "I can’t assist with this topic."
                    )
                })
                continue  # ⛔ STOP here (no routing, no RAG)

            history.append(f"user: {user_en}")

            # 3️⃣ Soft routing (LLM)
            category = route_query(user_en)

            if category == "out_of_scope":
                answer_en = (
                    "I’m here to help with women’s health–related questions only. "
                    "I can’t assist with this topic."
                )

            elif category == "greeting":
                answer_en = "Hello. How can I support you today?"

            elif category == "farewell":
                answer_en = "Take care. I’m here whenever you need support."

            else:
                # 4️⃣ ONLY here RAG is allowed
                answer_en = get_rag_answer(user_en, history)

            history.append(f"assistant: {answer_en}")

            final = translate_from_english(answer_en, language)

            await ws.send_json({
                "type": "final",
                "text": final
            })

    finally:
        await ws.close()
        print("WebSocket closed cleanly")

