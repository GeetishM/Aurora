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

# ================= LANGUAGES (INDIA FIRST) ================= #

LANGUAGES = {
    # 🇮🇳 Indian languages (priority)
    "English": "en",
    "Hindi": "hi",
    "Hinglish": "hinglish",
    "Bengali": "bn",
    "Marathi": "mr",
    "Tamil": "ta",
    "Telugu": "te",
    "Gujarati": "gu",
    "Kannada": "kn",
    "Malayalam": "ml",
    "Punjabi": "pa",
    "Urdu": "ur",
    "Odia": "or",
    "Assamese": "as",
    "Nepali": "ne",
    "Konkani": "kok",
    "Kashmiri": "ks",
    "Sindhi": "sd",
    "Maithili": "mai",
    "Santali": "sat",
    "Manipuri (Meitei)": "mni",
    "Bodo": "brx",
    "Dogri": "doi",

    # 🌍 Global languages (optional)
    "Spanish": "es",
    "French": "fr",
    "German": "de",
    "Arabic": "ar",
    "Portuguese": "pt",
    "Indonesian": "id",
    "Japanese": "ja",
    "Korean": "ko",
    "Chinese": "zh",
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

# ================= TRANSLATION (PRODUCTION SAFE) ================= #

LANG_META = {
    # 🇮🇳 Indian languages
    "hi":  {"name": "Hindi", "script": "Devanagari"},
    "bn":  {"name": "Bengali", "script": "Bengali"},
    "mr":  {"name": "Marathi", "script": "Devanagari"},
    "ta":  {"name": "Tamil", "script": "Tamil"},
    "te":  {"name": "Telugu", "script": "Telugu"},
    "gu":  {"name": "Gujarati", "script": "Gujarati"},
    "kn":  {"name": "Kannada", "script": "Kannada"},
    "ml":  {"name": "Malayalam", "script": "Malayalam"},
    "pa":  {"name": "Punjabi", "script": "Gurmukhi"},
    "ur":  {"name": "Urdu", "script": "Arabic"},
    "or":  {"name": "Odia", "script": "Odia"},
    "as":  {"name": "Assamese", "script": "Bengali-Assamese"},
    "ne":  {"name": "Nepali", "script": "Devanagari"},
    "kok": {"name": "Konkani", "script": "Devanagari"},
    "ks":  {"name": "Kashmiri", "script": "Arabic"},
    "sd":  {"name": "Sindhi", "script": "Arabic"},
    "mai": {"name": "Maithili", "script": "Devanagari"},
    "sat": {"name": "Santali", "script": "Ol Chiki"},
    "mni": {"name": "Manipuri (Meitei)", "script": "Meitei Mayek"},
    "brx": {"name": "Bodo", "script": "Devanagari"},
    "doi": {"name": "Dogri", "script": "Devanagari"},

    # 🌍 Global languages
    "es": {"name": "Spanish", "script": "Latin"},
    "fr": {"name": "French", "script": "Latin"},
    "de": {"name": "German", "script": "Latin"},
    "ar": {"name": "Arabic", "script": "Arabic"},
    "pt": {"name": "Portuguese", "script": "Latin"},
    "id": {"name": "Indonesian", "script": "Latin"},
    "ja": {"name": "Japanese", "script": "Japanese"},
    "ko": {"name": "Korean", "script": "Hangul"},
    "zh": {"name": "Chinese", "script": "Simplified Chinese"},
}



def translate_to_english(text: str, src_lang: str) -> str:
    if src_lang == "en":
        return text

    if src_lang == "hinglish":
        instruction = (
            "Translate the following Hinglish (Hindi written using English letters) "
            "into clear, natural English. "
            "Do not explain. Output ONLY the translated sentence."
        )
    else:
        instruction = (
            "Translate the following text into clear, natural English. "
            "Do not explain. Output ONLY the translated sentence."
        )

    return groq_chat(
        [
            {"role": "system", "content": "You are a strict translation engine."},
            {"role": "user", "content": f"{instruction}\n\n{text}"}
        ]
    )


def translate_from_english(text: str, tgt_lang: str) -> str:
    if tgt_lang == "en":
        return text

    if tgt_lang == "hinglish":
        instruction = (
            "Translate the following English text into Hinglish "
            "(Hindi language written using English letters). "
            "Do not explain. Output ONLY the translated sentence."
        )

    elif tgt_lang in LANG_META:
        meta = LANG_META[tgt_lang]
        instruction = (
            f"Translate the following English text into {meta['name']} "
            f"using {meta['script']} script. "
            "Do not explain. Output ONLY the translated sentence."
        )

    else:
        instruction = (
            "Translate the following English text into the target language. "
            "Do not explain. Output ONLY the translated sentence."
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
farewell
daily_symptom_support
holistic_wellness_lifestyle
hormonal_life_stages
mental_emotional_resilience
preventive_care_screening
safety_support_advocacy
out_of_scope

Rules:
- bye, goodbye, see you, exit → farewell
- hi, hello → greeting
- Non-healthcare topics → out_of_scope

Query:
{query}

Answer ONLY the category name.
"""

    response = groq_chat([{"role": "user", "content": prompt}]).strip().lower()

    valid_categories = {
        "greeting",
        "farewell",
        "daily_symptom_support",
        "holistic_wellness_lifestyle",
        "hormonal_life_stages",
        "mental_emotional_resilience",
        "preventive_care_screening",
        "safety_support_advocacy",
        "out_of_scope",
    }

    if response not in valid_categories:
        return "out_of_scope"

    return response

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

# ================= Background color ================= #

# st.markdown(
# """
# <style>

# /* ===== FULL RESET ===== */
# html, body, [data-testid="stAppViewContainer"], [data-testid="stApp"] {
#     height: 100%;
#     width: 100%;
#     margin: 0;
#     padding: 0;
#     background: transparent;
# }

# /* Hide Streamlit header bar */
# header { visibility: hidden; }

# /* Remove container padding */
# .block-container {
#     padding-top: 0 !important;
#     padding-bottom: 0 !important;
#     max-width: 100% !important;
# }

# /* ===== NORTHERN LIGHTS SIDEWAYS FLOW ===== */
# @keyframes auroraFlow {
#     0%   { background-position: 0% 50%, 0% 50%, 0% 50%, 0% 0%; }
#     50%  { background-position: 100% 50%, 80% 60%, 60% 40%, 100% 100%; }
#     100% { background-position: 0% 50%, 0% 50%, 0% 50%, 0% 0%; }
# }

# /* ===== FULLSCREEN AURORA ===== */
# .stApp {
#     min-height: 100vh;
#     background:
#         linear-gradient(
#             120deg,
#             rgba(0, 255, 180, 0.35),
#             rgba(0, 180, 255, 0.35),
#             rgba(120, 255, 220, 0.25),
#             rgba(0, 140, 200, 0.3)
#         ),
#         radial-gradient(60% 120% at 10% 50%, rgba(0, 255, 200, 0.35), transparent 60%),
#         radial-gradient(50% 100% at 90% 60%, rgba(0, 180, 255, 0.35), transparent 65%),
#         linear-gradient(180deg, #020814 0%, #041a2d 50%, #020814 100%);

#     background-size: 400% 400%;
#     animation: auroraFlow 40s linear infinite;
#     color: #eef2f7;
# }

# /* ===== CHAT MESSAGES ===== */
# .stChatMessage {
#     background: rgba(255, 255, 255, 0.08);
#     backdrop-filter: blur(12px);
#     border-radius: 14px;
#     padding: 12px;
#     box-shadow: 0 0 24px rgba(0, 255, 200, 0.15);
# }

# /* ===== INPUT AREA (NO BLACK BAR) ===== */
# section[data-testid="stChatInput"] {
#     background: transparent !important;
# }

# textarea {
#     background: rgba(5, 18, 35, 0.85) !important;
#     color: #ffffff !important;
#     border-radius: 14px !important;
#     border: 1px solid rgba(0, 255, 200, 0.45) !important;
# }

# /* Placeholder */
# textarea::placeholder {
#     color: #a8b2c1;
# }

# /* ===== DROPDOWN ===== */
# div[data-baseweb="select"] > div {
#     background: rgba(5, 18, 35, 0.85);
#     border: 1px solid rgba(0, 255, 200, 0.4);
#     border-radius: 12px;
#     color: white;
# }

# /* ===== TITLE GLOW ===== */
# h1 {
#     text-shadow: 
#         0 0 10px rgba(0, 255, 200, 0.35),
#         0 0 30px rgba(0, 200, 255, 0.25);
# }

# </style>
# """,
# unsafe_allow_html=True
# )


# ================= HEADER ================= #

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
        {"role": "assistant", "content": "Hello, I’m Aurora. How can I support your health today?"}
    ]

if "history_en" not in st.session_state:
    st.session_state.history_en = [
        {"role": "system", "content": "You are Aurora, a calm women’s healthcare assistant."}
    ]

if "has_interacted" not in st.session_state:
    st.session_state.has_interacted = False

# ================= CHAT RENDER ================= #

for msg in st.session_state.chat_en:
    translated = translate_from_english(msg["content"], lang_code)
    with st.chat_message(msg["role"]):
        st.markdown(translated)

# ================= INPUT ================= #

user_input = st.chat_input("Ask about women’s health...")

if user_input:
    user_input_en = translate_to_english(user_input, lang_code)

    with st.chat_message("user"):
        st.markdown(user_input)

    st.session_state.chat_en.append({"role": "user", "content": user_input_en})
    st.session_state.history_en.append({"role": "user", "content": user_input_en})

    with st.chat_message("assistant"):
        placeholder = st.empty()
        placeholder.markdown("Answering…")

    category = route_query(user_input_en)

    if category == "farewell":
        answer_en = "Take care. If you need support in the future, I’ll be here."

    elif category == "greeting":
        answer_en = (
            "Welcome back. How can I support you today?"
            if st.session_state.has_interacted
            else "Hello. How can I support you today?"
        )

    elif category == "out_of_scope":
        answer_en = (
            "I focus specifically on women’s healthcare topics. "
            "If you have a related question, I’ll be glad to help."
        )

    else:
        answer_en = get_rag_answer(user_input_en, st.session_state.history_en)

    final_answer = translate_from_english(answer_en, lang_code)

    placeholder.empty()

    with st.chat_message("assistant"):
        st.markdown(final_answer)

    st.session_state.chat_en.append({"role": "assistant", "content": answer_en})
    st.session_state.history_en.append({"role": "assistant", "content": answer_en})

    st.session_state.has_interacted = True
    st.rerun()
