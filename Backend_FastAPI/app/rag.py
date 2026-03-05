import logging
from dotenv import load_dotenv
from langchain_core.prompts import ChatPromptTemplate

from .llm import groq_chat, groq_chat_stream
from .qdrant_store import load_retriever
from .response_banks import random_no_context

load_dotenv()
logger = logging.getLogger(__name__)

# Load once at startup
retriever = load_retriever()

# ── Constants ─────────────────────────────────────────────────────────────────

MAX_HISTORY  = 14   # total messages before summarisation kicks in
SUMMARY_KEEP = 4    # how many recent messages to keep verbatim after summary


# ── Query rewriting ───────────────────────────────────────────────────────────

def rewrite_query(query: str, history: list[str]) -> str:
    """
    Rewrites the user's query into a clear, standalone, search-optimised
    question using recent conversation context. Falls back to original on
    rate limit or short history.
    """
    if len(history) <= 1:
        return query

    # Use last 4 turns for context
    recent = "\n".join(history[-4:])

    prompt = f"""
Given the conversation below and the user's latest message, rewrite the latest message
as a clear, standalone, search-optimised query about women's healthcare.
Remove vague pronouns like 'it', 'this', 'that'. Be specific and complete.
Output ONLY the rewritten query — nothing else.

Conversation:
{recent}

Latest message: {query}
"""
    rewritten = groq_chat([{"role": "user", "content": prompt}], temperature=0.0)

    if rewritten is None or len(rewritten.strip()) <= 5:
        return query  # rate limit or bad result — fall back to original

    return rewritten.strip()


# ── Conversation summarisation ────────────────────────────────────────────────

def maybe_summarise_history(history: list[str]) -> list[str]:
    """
    When conversation exceeds MAX_HISTORY turns, summarises the older
    portion into a single bullet-point summary and returns the trimmed list.
    """
    if len(history) <= MAX_HISTORY:
        return history

    to_summarise = history[:len(history) - SUMMARY_KEEP]
    to_keep      = history[len(history) - SUMMARY_KEEP:]

    convo_text = "\n".join(to_summarise)
    prompt = (
        "Summarise the following women's healthcare conversation in 3–5 bullet points, "
        "preserving key medical topics and any important details the user shared. "
        "Be concise.\n\n" + convo_text
    )

    summary = groq_chat([{"role": "user", "content": prompt}], temperature=0.0)

    if summary is None:
        # Rate limited — skip summarisation this turn
        return history

    summary_entry = f"[Conversation summary]\n{summary}"
    return [summary_entry] + to_keep


# ── RAG prompt ────────────────────────────────────────────────────────────────

_PROMPT_TEMPLATE = ChatPromptTemplate.from_template("""
You are Aurora, a warm and knowledgeable women's healthcare assistant.
You speak like a caring, informed friend — clear, human, and never clinical or cold.
Use plain language. Avoid bullet-point dumps unless a list genuinely helps.
Write in a natural, conversational tone.

Context:
{context}

Recent conversation:
{history}

User question:
{question}

Rules:
- Use ONLY the provided context
- Do NOT diagnose
- Be warm, supportive, and human — not robotic
- Acknowledge the user's concern before answering where appropriate
- End with a gentle follow-up offer if relevant
  (e.g. "Let me know if you'd like more detail on any of this.")
""")

_SYSTEM_MESSAGE = {
    "role": "system",
    "content": (
        "You are Aurora, a warm and knowledgeable women's healthcare assistant. "
        "You speak like a caring, informed friend — clear, empathetic, and never clinical or cold. "
        "Always acknowledge the human behind the question."
    ),
}


# ── Source extraction ─────────────────────────────────────────────────────────

def _extract_sources(docs) -> list[dict]:
    sources, seen = [], set()
    for doc in docs:
        meta = doc.metadata or {}
        src  = meta.get("source") or meta.get("source_type", "")
        cat  = meta.get("category", "")
        sub  = meta.get("subcategory", "")
        key  = f"{src}:{cat}:{sub}"
        if key not in seen:
            seen.add(key)
            sources.append({"source": src, "category": cat, "subcategory": sub})
    return sources


# ── Public API ────────────────────────────────────────────────────────────────

def get_rag_answer_stream(query: str, history: list[str]):
    """
    Yields (token: str, sources: list | None).
    sources is only non-None on the very last yield so callers know it's done.

    Usage:
        for token, sources in get_rag_answer_stream(query, history):
            if sources is not None:
                # streaming finished
                ...
            else:
                send_chunk(token)
    """
    # 1️⃣  Rewrite query for better retrieval
    search_query = rewrite_query(query, history)
    logger.debug("Rewritten query: %s", search_query)

    # 2️⃣  Retrieve docs
    docs = retriever.invoke(search_query)

    if not docs:
        no_ctx = random_no_context()
        yield no_ctx, []   # final yield with empty sources
        return

    context = "\n\n".join(d.page_content for d in docs)
    sources = _extract_sources(docs)

    # 3️⃣  Build prompt
    formatted = _PROMPT_TEMPLATE.format(
        context=context,
        history="\n".join(history[-6:]),
        question=query,
    )
    messages = [_SYSTEM_MESSAGE, {"role": "user", "content": formatted}]

    # 4️⃣  Stream tokens — yield (token, None) for each chunk
    full_answer = ""
    for token in groq_chat_stream(messages):
        full_answer += token
        yield token, None   # None = not the final yield yet

    # 5️⃣  Final yield carries sources so caller knows streaming ended
    yield "", sources