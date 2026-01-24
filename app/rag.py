# Qdrant + RAG
from pathlib import Path
from qdrant_client import QdrantClient
from langchain_qdrant import QdrantVectorStore
from langchain_ollama import OllamaEmbeddings
from .llm import groq_chat

embeddings = OllamaEmbeddings(model="mxbai-embed-large")

client = QdrantClient(path="qdrant_db")
vectorstore = QdrantVectorStore(
    client=client,
    collection_name="aurora_womens_health",
    embedding=embeddings
)

retriever = vectorstore.as_retriever(search_kwargs={"k": 4})

def get_rag_answer(query: str, history: list) -> str:
    docs = retriever.invoke(query)

    if not docs:
        return (
            "I may not have enough information on this yet. "
            "Please consult a healthcare professional."
        )

    context = "\n\n".join(d.page_content for d in docs)

    prompt = f"""
You are Aurora, a women’s healthcare assistant.

Context:
{context}

Conversation:
{history}

Question:
{query}

Rules:
- Use only context
- No diagnosis
- Calm and supportive tone
"""

    return groq_chat([
        {"role": "system", "content": "You are Aurora."},
        {"role": "user", "content": prompt}
    ])

