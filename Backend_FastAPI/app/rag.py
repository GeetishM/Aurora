import os
from dotenv import load_dotenv
from groq import Groq
from langchain_core.prompts import ChatPromptTemplate
from .qdrant_store import load_vectorstore
from .llm import groq_chat

load_dotenv()

# Groq client
groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))

# Load retriever once
retriever = load_vectorstore().as_retriever(search_kwargs={"k": 4})


def get_rag_answer(query: str, history: list) -> str:
    docs = retriever.invoke(query)

    if not docs:
        return (
            "I don’t have verified information on this in my knowledge base. "
            "Please consult a healthcare professional."
        )

    context = "\n\n".join(d.page_content for d in docs)

    prompt = ChatPromptTemplate.from_template("""
You are Aurora, a women’s healthcare assistant.

STRICT RULES:
- Answer ONLY using the information in <Context>
- If the answer is not present in <Context>, say you do not have enough information
- Do NOT answer math, coding, or technical questions
- Do NOT use general knowledge
- Do NOT diagnose or prescribe

<Context>
{context}
</Context>

Conversation history:
{history}

User question:
{question}

Answer:
""")

    formatted = prompt.format(
        context=context,
        history="\n".join(
            f"{m['role']}: {m['content']}" for m in history[-6:]
        ),
        question=query
    )

    return groq_chat(
        [
            {"role": "system", "content": "You answer strictly from provided context."},
            {"role": "user", "content": formatted}
        ],
        temperature=0.2
    )

