import os
from dotenv import load_dotenv
from groq import Groq
from langchain_core.prompts import ChatPromptTemplate

from .llm import groq_chat_stream

from .qdrant_store import load_vectorstore

load_dotenv()

# Groq client
groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))

# Load retriever once
retriever = load_vectorstore().as_retriever(search_kwargs={"k": 4})


def get_rag_answer_stream(query: str, history: list):
    docs = retriever.invoke(query)

    if not docs:
        yield (
            "I may not have detailed information on this yet. "
            "For medical concerns, consulting a healthcare professional is recommended."
        )
        return

    context = "\n\n".join(d.page_content for d in docs)

    prompt = f"""
You are Aurora, a professional women’s healthcare assistant.

Context:
{context}

Recent conversation:
{history}

User question:
{query}

Rules:
- Use ONLY the provided context
- Do NOT diagnose
- Calm, respectful, supportive tone
"""

    messages = [
        {"role": "system", "content": "You are Aurora, a women’s healthcare assistant."},
        {"role": "user", "content": prompt},
    ]

    yield from groq_chat_stream(messages)
