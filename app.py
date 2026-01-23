import os
import streamlit as st
from pathlib import Path
from dotenv import load_dotenv
from groq import Groq

from qdrant_client import QdrantClient
from langchain_qdrant import QdrantVectorStore
from langchain_ollama import OllamaEmbeddings
from langchain_core.prompts import ChatPromptTemplate

# ================= ENV ================= #

load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
assert GROQ_API_KEY, "❌ GROQ_API_KEY missing"

groq_client = Groq(api_key=GROQ_API_KEY)

QDRANT_PATH = "qdrant_db"
COLLECTION_NAME = "aurora_womens_health"

# ================= LANGUAGES ================= #

LANGUAGES = {
    "English": "en",
    "Hindi": "hi",
    "Tamil": "ta",
    "Telugu": "te",
    "Bengali": "bn",
    "Marathi": "mr",
    "Hinglish": "hinglish",
}

# ================= EMBEDDINGS ================= #

@st.cache_resource
def load_embeddings():
    return OllamaEmbeddings(model="mxbai-embed-large")

embeddings = load_embeddings()

# ================= VECTOR STORE ================= #

@st.cache_resource
def load_vectorstore():
    base_dir = Path(__file__).resolve().parent
    qdrant_dir = base_dir / QDRANT_PATH
    client = QdrantClient(path=str(qdrant_dir))

    return QdrantVectorStore(
        client=client,
        collection_name=COLLECTION_NAME,
        embedding=embeddings
    )

vectorstore = load_vectorstore()
retriever = vectorstore.as_retriever(search_kwargs={"k": 4})

# ================= GROQ CORE ================= #

def groq_chat(messages, temperature=0.0) -> str:
    response = groq_client.chat.completions.create(
        model="llama-3.1-8b-instant",
        messages=messages,
        temperature=temperature
    )
    return response.choices[0].message.content.strip()

# ================= TRANSLATION (STRICT) ================= #

def translate_to_english(text: str, src_lang: str) -> str:
    if src_lang == "en":
        return text

    if src_lang == "hinglish":
        instruction = (
            "Translate the following Hinglish sentence into clear, natural English. "
            "Do not explain. Output ONLY the translated sentence."
        )
    else:
        instruction = (
            "Translate the following text into English. "
            "Do not explain. Output ONLY the translated text."
        )

    return groq_chat(
        [
            {"role": "system", "content": "You are a professional translation engine."},
            {"role": "user", "content": f"{instruction}\n\n{text}"}
        ]
    )


def translate_from_english(text: str, tgt_lang: str) -> str:
    if tgt_lang == "en":
        return text

    if tgt_lang == "hinglish":
        instruction = (
            "Translate the following English text into Hinglish "
            "(Hindi written using English letters). "
            "Do not explain. Output ONLY the translated sentence."
        )
    else:
        instruction = (
            f"Translate the following English text into {tgt_lang}. "
            "Do not explain. Output ONLY the translated text."
        )

    return groq_chat(
        [
            {"role": "system", "content": "You are a professional translation engine."},
            {"role": "user", "content": f"{instruction}\n\n{text}"}
        ]
    )

# ================= ROUTER ================= #

def route_query(query: str) -> str:
    prompt = f"""
Classify this women's healthcare query into ONE category:

greeting
daily_symptom_support
holistic_wellness_lifestyle
hormonal_life_stages
mental_emotional_resilience
preventive_care_screening
safety_support_advocacy
out_of_scope

Query:
{query}

Answer ONLY the category name.
"""
    return groq_chat(
        [{"role": "user", "content": prompt}]
    ).lower()

# ================= RAG ================= #

def get_rag_answer(query: str, history: list) -> str:
    docs = retriever.invoke(query)

    if not docs:
        return (
            "I may not have detailed information on this yet. "
            "For medical concerns, consulting a healthcare professional is recommended."
        )

    context = "\n\n".join(d.page_content for d in docs)

    prompt = ChatPromptTemplate.from_template("""
You are Aurora, a professional women’s healthcare assistant.

Context:
{context}

Recent conversation:
{history}

User question:
{question}

Rules:
- Use ONLY the provided context
- Do NOT diagnose
- Calm, respectful, supportive tone
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
            {"role": "system", "content": "You are Aurora, a women’s healthcare assistant."},
            {"role": "user", "content": formatted}
        ],
        temperature=0.3
    )

# ================= UI ================= #

st.set_page_config(page_title="Aurora 🌸", layout="wide")

col1, col2 = st.columns([0.82, 0.18])
with col1:
    st.title("🌸 Aurora – Women’s Healthcare Assistant")
with col2:
    selected_language = st.selectbox(
        "Language",
        list(LANGUAGES.keys()),
        label_visibility="collapsed"
    )

lang_code = LANGUAGES[selected_language]

# ================= SESSION ================= #

if "chat_en" not in st.session_state:
    st.session_state.chat_en = [
        {
            "role": "assistant",
            "content": "Hello, I’m Aurora. How can I support your health today?"
        }
    ]

if "history_en" not in st.session_state:
    st.session_state.history_en = [
        {
            "role": "system",
            "content": "You are Aurora, a calm women’s healthcare assistant."
        }
    ]

if "has_interacted" not in st.session_state:
    st.session_state.has_interacted = False

# ================= CHAT RENDER (LIVE TRANSLATION) ================= #

for msg in st.session_state.chat_en:
    translated = translate_from_english(msg["content"], lang_code)
    with st.chat_message(msg["role"]):
        st.markdown(translated)

# ================= INPUT ================= #

user_input = st.chat_input("Ask about women’s health...")

if user_input:
    # Translate user input to English
    user_input_en = translate_to_english(user_input, lang_code)

    # 1️⃣ Show user message immediately
    with st.chat_message("user"):
        st.markdown(user_input)

    # Save backend history (English)
    st.session_state.chat_en.append(
        {"role": "user", "content": user_input_en}
    )
    st.session_state.history_en.append(
        {"role": "user", "content": user_input_en}
    )

    # 2️⃣ Show temporary assistant placeholder
    with st.chat_message("assistant"):
        placeholder = st.empty()
        placeholder.markdown("Answering…")

    # ---- LLM work (NO UI rendering here) ----
    category = route_query(user_input_en)

    if category == "greeting":
        answer_en = (
            "Welcome back. How can I support you today?"
            if st.session_state.has_interacted
            else "Hello. How can I support you today?"
        )

    elif category == "out_of_scope":
        answer_en = (
            "I focus on women’s healthcare topics such as symptoms, hormones, "
            "mental wellbeing, pregnancy, and preventive care."
        )

    else:
        answer_en = get_rag_answer(
            user_input_en,
            st.session_state.history_en
        )

    final_answer = translate_from_english(answer_en, lang_code)

    # 3️⃣ Remove "Answering…"
    placeholder.empty()

    # 4️⃣ Render final assistant message CLEANLY
    with st.chat_message("assistant"):
        st.markdown(final_answer)

    # Save backend history
    st.session_state.chat_en.append(
        {"role": "assistant", "content": answer_en}
    )
    st.session_state.history_en.append(
        {"role": "assistant", "content": answer_en}
    )

    st.session_state.has_interacted = True
    st.rerun()
