import os
import random
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
    "English": "en", "Hindi": "hi", "Hinglish": "hinglish",
    "Bengali": "bn", "Marathi": "mr", "Tamil": "ta", "Telugu": "te",
    "Gujarati": "gu", "Kannada": "kn", "Malayalam": "ml", "Punjabi": "pa",
    "Urdu": "ur", "Odia": "or", "Assamese": "as", "Nepali": "ne",
    "Konkani": "kok", "Kashmiri": "ks", "Sindhi": "sd", "Maithili": "mai",
    "Santali": "sat", "Manipuri (Meitei)": "mni", "Bodo": "brx", "Dogri": "doi",
    "Spanish": "es", "French": "fr", "German": "de", "Arabic": "ar",
    "Portuguese": "pt", "Indonesian": "id", "Japanese": "ja",
    "Korean": "ko", "Chinese": "zh",
}

LANG_META = {
    "hi":  {"name": "Hindi",             "script": "Devanagari"},
    "bn":  {"name": "Bengali",           "script": "Bengali"},
    "mr":  {"name": "Marathi",           "script": "Devanagari"},
    "ta":  {"name": "Tamil",             "script": "Tamil"},
    "te":  {"name": "Telugu",            "script": "Telugu"},
    "gu":  {"name": "Gujarati",          "script": "Gujarati"},
    "kn":  {"name": "Kannada",           "script": "Kannada"},
    "ml":  {"name": "Malayalam",         "script": "Malayalam"},
    "pa":  {"name": "Punjabi",           "script": "Gurmukhi"},
    "ur":  {"name": "Urdu",              "script": "Arabic"},
    "or":  {"name": "Odia",              "script": "Odia"},
    "as":  {"name": "Assamese",          "script": "Bengali-Assamese"},
    "ne":  {"name": "Nepali",            "script": "Devanagari"},
    "kok": {"name": "Konkani",           "script": "Devanagari"},
    "ks":  {"name": "Kashmiri",          "script": "Arabic"},
    "sd":  {"name": "Sindhi",            "script": "Arabic"},
    "mai": {"name": "Maithili",          "script": "Devanagari"},
    "sat": {"name": "Santali",           "script": "Ol Chiki"},
    "mni": {"name": "Manipuri (Meitei)", "script": "Meitei Mayek"},
    "brx": {"name": "Bodo",             "script": "Devanagari"},
    "doi": {"name": "Dogri",             "script": "Devanagari"},
    "es":  {"name": "Spanish",           "script": "Latin"},
    "fr":  {"name": "French",            "script": "Latin"},
    "de":  {"name": "German",            "script": "Latin"},
    "ar":  {"name": "Arabic",            "script": "Arabic"},
    "pt":  {"name": "Portuguese",        "script": "Latin"},
    "id":  {"name": "Indonesian",        "script": "Latin"},
    "ja":  {"name": "Japanese",          "script": "Japanese"},
    "ko":  {"name": "Korean",            "script": "Hangul"},
    "zh":  {"name": "Chinese",           "script": "Simplified Chinese"},
}

# ================= RESPONSE BANKS ================= #

FIRST_GREETINGS = [
    "Hi there! I'm Aurora 🌸 I'm here to support you with any women's health questions you have. What's on your mind today?",
    "Hello! Welcome — I'm Aurora, your women's health companion. Feel free to ask me anything, I'm here to help. 💙",
    "Hi! I'm so glad you're here. I'm Aurora, and I'm here to help you navigate any health questions or concerns. What would you like to talk about?",
    "Hello and welcome! I'm Aurora 🌸 Think of me as a knowledgeable friend who's always here to talk through your health questions. How can I support you today?",
    "Hi there! I'm Aurora — a women's health assistant here to provide a safe, supportive space for your questions. What can I help you with?",
]

RETURN_GREETINGS = [
    "Welcome back! 🌸 It's good to hear from you again. What's on your mind today?",
    "Hey, good to see you again! How have you been? What can I help you with today?",
    "Welcome back! I'm here whenever you need me. What would you like to talk about?",
    "Hello again! 😊 I'm glad you came back. What health questions can I help you with today?",
    "Good to have you back! How are you feeling? What can I support you with today?",
]

FAREWELLS = [
    "Take care of yourself — you deserve it. 🌸 I'll be right here whenever you need me.",
    "Goodbye for now! Remember, your health matters and so do you. Come back anytime. 💙",
    "Take care! It was lovely chatting with you. Don't hesitate to reach out whenever you need support. 🌸",
    "Wishing you good health and peace of mind. See you next time! 😊",
    "Bye for now! Remember to be kind to yourself. I'm always here if you have more questions. 💙",
    "Take care and stay well! It's been a pleasure. Come back anytime — I'm always here for you. 🌸",
]

OUT_OF_SCOPE = [
    "That's a little outside the area I'm built to support, but I genuinely want to help you. "
    "If there's anything on your mind related to your health and wellbeing as a woman, please do ask — I'm all ears. 🌸",

    "I'm best at supporting questions around women's health and wellness, so I may not be the right fit for that one. "
    "But if something health-related is weighing on you, I'm right here and happy to help. 💙",

    "That's not quite in my area of expertise, but your wellbeing is what matters most to me. "
    "If you have any questions about your health — big or small — please feel free to share. I'm here for you. 🌸",

    "I'm a little limited outside of women's health topics, but I never want you to feel like you have nowhere to turn. "
    "Is there a health question or concern I can help you with instead? 💙",

    "That one's a bit beyond what I'm designed for — I'd hate to give you an unhelpful answer! "
    "But if there's anything women's health-related on your mind, I'm genuinely here to support you. 🌸",
]

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

# UPGRADE 1: MMR retrieval + score threshold
retriever = vectorstore.as_retriever(
    search_type="mmr",
    search_kwargs={"k": 4, "fetch_k": 8, "score_threshold": 0.30},
)

# ================= GROQ CORE ================= #

def groq_chat(messages, temperature=0.0) -> str:
    response = groq_client.chat.completions.create(
        model="llama-3.1-8b-instant",
        messages=messages,
        temperature=temperature
    )
    return response.choices[0].message.content.strip()

# UPGRADE 2: Streaming response
def groq_stream(messages, temperature=0.3):
    stream = groq_client.chat.completions.create(
        model="llama-3.1-8b-instant",
        messages=messages,
        temperature=temperature,
        stream=True,
    )
    for chunk in stream:
        delta = chunk.choices[0].delta.content
        if delta:
            yield delta

# ================= TRANSLATION ================= #

# UPGRADE 3: Translation cache
def _tx_cache_key(text: str, lang: str) -> str:
    return f"{lang}:{hash(text)}"

def translate_to_english(text: str, src_lang: str) -> str:
    if src_lang == "en":
        return text
    key = _tx_cache_key(text, f"{src_lang}>en")
    if key in st.session_state.get("tx_cache", {}):
        return st.session_state["tx_cache"][key]

    if src_lang == "hinglish":
        instruction = (
            "Translate the following Hinglish (Hindi written using English letters) "
            "into clear, natural English. Do not explain. Output ONLY the translation."
        )
    else:
        instruction = (
            "Translate the following text into clear, natural English. "
            "Do not explain. Output ONLY the translation."
        )
    result = groq_chat([
        {"role": "system", "content": "You are a strict translation engine."},
        {"role": "user",   "content": f"{instruction}\n\n{text}"}
    ])
    st.session_state.setdefault("tx_cache", {})[key] = result
    return result


def translate_from_english(text: str, tgt_lang: str) -> str:
    if tgt_lang == "en":
        return text
    key = _tx_cache_key(text, f"en>{tgt_lang}")
    if key in st.session_state.get("tx_cache", {}):
        return st.session_state["tx_cache"][key]

    if tgt_lang == "hinglish":
        instruction = (
            "Translate the following English text into Hinglish "
            "(Hindi language written using English letters). "
            "Do not explain. Output ONLY the translation."
        )
    elif tgt_lang in LANG_META:
        meta = LANG_META[tgt_lang]
        instruction = (
            f"Translate the following English text into {meta['name']} "
            f"using {meta['script']} script. "
            "Do not explain. Output ONLY the translation."
        )
    else:
        instruction = (
            "Translate the following English text into the target language. "
            "Do not explain. Output ONLY the translation."
        )
    result = groq_chat([
        {"role": "system", "content": "You are a professional translation engine."},
        {"role": "user",   "content": f"{instruction}\n\n{text}"}
    ])
    st.session_state.setdefault("tx_cache", {})[key] = result
    return result

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
        "greeting", "farewell", "daily_symptom_support",
        "holistic_wellness_lifestyle", "hormonal_life_stages",
        "mental_emotional_resilience", "preventive_care_screening",
        "safety_support_advocacy", "out_of_scope",
    }
    return response if response in valid_categories else "out_of_scope"

# ================= QUERY REWRITING ================= #

# UPGRADE 4: Query rewriting
def rewrite_query(query: str, history: list) -> str:
    if len(history) <= 1:
        return query

    recent = "\n".join(
        f"{m['role']}: {m['content']}" for m in history[-4:] if m["role"] != "system"
    )
    prompt = f"""
Given the conversation below and the user's latest message, rewrite the latest message
as a clear, standalone, search-optimised query about women's healthcare.
Remove pronouns like 'it', 'this', 'that'. Be specific and complete.
Output ONLY the rewritten query, nothing else.

Conversation:
{recent}

Latest message: {query}
"""
    rewritten = groq_chat([{"role": "user", "content": prompt}]).strip()
    return rewritten if len(rewritten) > 5 else query

# ================= RAG ================= #

# UPGRADE 5: Source citations
def get_rag_answer(query: str, history: list) -> tuple[str, list[dict]]:
    search_query = rewrite_query(query, history)
    docs = retriever.invoke(search_query)

    if not docs:
        return (
            "I want to make sure I give you accurate information, and I don't have enough "
            "detail on that specific topic right now. For anything that feels urgent or medical, "
            "please do reach out to a healthcare professional — they'll be able to give you "
            "the personalised support you deserve. 💙",
            []
        )

    context = "\n\n".join(d.page_content for d in docs)

    sources: list[dict] = []
    seen = set()
    for doc in docs:
        meta = doc.metadata or {}
        src  = meta.get("source") or meta.get("source_type", "")
        cat  = meta.get("category", "")
        sub  = meta.get("subcategory", "")
        key  = f"{src}:{cat}:{sub}"
        if key not in seen:
            seen.add(key)
            sources.append({"source": src, "category": cat, "subcategory": sub})

    prompt = ChatPromptTemplate.from_template("""
You are Aurora, a warm and knowledgeable women's healthcare assistant.
You speak like a caring, informed friend — clear, human, and never clinical or cold.
Use plain language. Avoid bullet-point dumps. Write in a natural, conversational tone.

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
- End with a gentle follow-up offer if relevant (e.g. "Let me know if you'd like more detail on any of this.")
""")

    formatted = prompt.format(
        context=context,
        history="\n".join(
            f"{m['role']}: {m['content']}"
            for m in history[-6:]
            if m["role"] != "system"
        ),
        question=query
    )

    return formatted, sources


def build_rag_messages(formatted_prompt: str) -> list[dict]:
    return [
        {"role": "system", "content": (
            "You are Aurora, a warm and knowledgeable women's healthcare assistant. "
            "You speak like a caring, informed friend — clear, empathetic, and never clinical or cold. "
            "Always acknowledge the human behind the question."
        )},
        {"role": "user", "content": formatted_prompt}
    ]

# ================= CONVERSATION SUMMARISATION ================= #

# UPGRADE 6: History summarisation
MAX_HISTORY = 14
SUMMARY_KEEP = 4

def maybe_summarise_history() -> None:
    history = st.session_state.history_en
    non_system = [m for m in history if m["role"] != "system"]
    if len(non_system) <= MAX_HISTORY:
        return

    to_summarise = non_system[:len(non_system) - SUMMARY_KEEP]
    to_keep      = non_system[len(non_system) - SUMMARY_KEEP:]

    convo_text = "\n".join(f"{m['role']}: {m['content']}" for m in to_summarise)
    summary_prompt = (
        "Summarise the following women's healthcare conversation in 3-5 bullet points, "
        "preserving key medical topics discussed and any important user details mentioned. "
        "Be concise.\n\n" + convo_text
    )
    summary = groq_chat([{"role": "user", "content": summary_prompt}])

    system_msgs = [m for m in history if m["role"] == "system"]
    summary_msg = {"role": "assistant", "content": f"[Conversation summary]\n{summary}"}
    st.session_state.history_en = system_msgs + [summary_msg] + to_keep

# ================= UI ================= #

st.set_page_config(page_title="Aurora 🌸", layout="wide")

# ================= HEADER ================= #

col1, col2 = st.columns([0.82, 0.18])
with col1:
    st.title("🌸 Aurora – Women's Healthcare Assistant")
with col2:
    selected_language = st.selectbox(
        "Language", list(LANGUAGES.keys()), label_visibility="collapsed"
    )

lang_code = LANGUAGES[selected_language]

# ================= SESSION INIT ================= #

if "chat_en" not in st.session_state:
    st.session_state.chat_en = [
        {"role": "assistant", "content": random.choice(FIRST_GREETINGS)}
    ]

if "history_en" not in st.session_state:
    st.session_state.history_en = [
        {"role": "system", "content": (
            "You are Aurora, a warm and knowledgeable women's healthcare assistant. "
            "You speak like a caring, informed friend — clear, empathetic, and never clinical or cold."
        )}
    ]

if "has_interacted" not in st.session_state:
    st.session_state.has_interacted = False

if "tx_cache" not in st.session_state:
    st.session_state.tx_cache = {}

if "sources_map" not in st.session_state:
    st.session_state.sources_map = {}

# ================= CHAT RENDER ================= #

for i, msg in enumerate(st.session_state.chat_en):
    translated = translate_from_english(msg["content"], lang_code)
    with st.chat_message(msg["role"]):
        st.markdown(translated)

        # Show sources if this assistant message has them
        sources = st.session_state.sources_map.get(i, [])
        if sources and msg["role"] == "assistant":
            with st.expander("📚 Sources used", expanded=False):
                for s in sources:
                    src = s.get("source", "")
                    cat = s.get("category", "").replace("_", " ").title()
                    sub = s.get("subcategory", "").replace("_", " ").title()
                    if src.startswith("http"):
                        st.markdown(f"🔗 [{src}]({src})")
                    elif src:
                        st.markdown(f"📄 `{src}`")
                    if cat:
                        st.caption(f"{cat}{' › ' + sub if sub else ''}")

# ================= INPUT ================= #

user_input = st.chat_input("Ask about women's health...")

if user_input:
    user_input_en = translate_to_english(user_input, lang_code)

    with st.chat_message("user"):
        st.markdown(user_input)

    st.session_state.chat_en.append({"role": "user", "content": user_input_en})
    st.session_state.history_en.append({"role": "user", "content": user_input_en})

    category = route_query(user_input_en)

    if category == "farewell":
        answer_en = random.choice(FAREWELLS)
        with st.chat_message("assistant"):
            st.markdown(translate_from_english(answer_en, lang_code))
        st.session_state.chat_en.append({"role": "assistant", "content": answer_en})
        st.session_state.history_en.append({"role": "assistant", "content": answer_en})

    elif category == "greeting":
        answer_en = (
            random.choice(RETURN_GREETINGS)
            if st.session_state.has_interacted
            else random.choice(FIRST_GREETINGS)
        )
        with st.chat_message("assistant"):
            st.markdown(translate_from_english(answer_en, lang_code))
        st.session_state.chat_en.append({"role": "assistant", "content": answer_en})
        st.session_state.history_en.append({"role": "assistant", "content": answer_en})

    elif category == "out_of_scope":
        answer_en = random.choice(OUT_OF_SCOPE)
        with st.chat_message("assistant"):
            st.markdown(translate_from_english(answer_en, lang_code))
        st.session_state.chat_en.append({"role": "assistant", "content": answer_en})
        st.session_state.history_en.append({"role": "assistant", "content": answer_en})

    else:
        # RAG path
        formatted_prompt, sources = get_rag_answer(user_input_en, st.session_state.history_en)
        messages = build_rag_messages(formatted_prompt)

        with st.chat_message("assistant"):
            if lang_code == "en":
                response_text = st.write_stream(groq_stream(messages))
            else:
                with st.spinner("Thinking…"):
                    chunks = list(groq_stream(messages))
                response_text = "".join(chunks)
                translated_answer = translate_from_english(response_text, lang_code)
                st.markdown(translated_answer)

        msg_idx = len(st.session_state.chat_en)
        st.session_state.sources_map[msg_idx] = sources

        st.session_state.chat_en.append({"role": "assistant", "content": response_text})
        st.session_state.history_en.append({"role": "assistant", "content": response_text})

        maybe_summarise_history()

    st.session_state.has_interacted = True
    st.rerun()