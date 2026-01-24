import os
import streamlit as st
from pathlib import Path
from dotenv import load_dotenv
from groq import Groq
from typing import TypedDict, List

from qdrant_client import QdrantClient
from langchain_qdrant import QdrantVectorStore
from langchain_ollama import OllamaEmbeddings
from langchain_core.prompts import ChatPromptTemplate

from langgraph.graph import StateGraph, END

# =========================================================
# ENV
# =========================================================

load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
assert GROQ_API_KEY, "GROQ_API_KEY missing"

groq_client = Groq(api_key=GROQ_API_KEY)

QDRANT_PATH = "qdrant_db"
COLLECTION_NAME = "aurora_womens_health"

LANGUAGES = {
    "English": "en",
    "Hindi": "hi",
    "Tamil": "ta",
    "Telugu": "te",
    "Bengali": "bn",
    "Marathi": "mr",
    "Hinglish": "hinglish",
}

# =========================================================
# VECTOR STORE
# =========================================================

@st.cache_resource
def load_embeddings():
    return OllamaEmbeddings(model="mxbai-embed-large")

@st.cache_resource
def load_vectorstore():
    base_dir = Path(__file__).resolve().parent
    client = QdrantClient(path=str(base_dir / QDRANT_PATH))
    return QdrantVectorStore(
        client=client,
        collection_name=COLLECTION_NAME,
        embedding=load_embeddings()
    )

retriever = load_vectorstore().as_retriever(search_kwargs={"k": 4})

# =========================================================
# GROQ CORE
# =========================================================

def groq_chat(messages, temperature=0.0) -> str:
    res = groq_client.chat.completions.create(
        model="llama-3.1-8b-instant",
        messages=messages,
        temperature=temperature
    )
    return res.choices[0].message.content.strip()

# =========================================================
# TRANSLATION
# =========================================================

def translate_to_english(text: str, src: str) -> str:
    if src == "en":
        return text
    instruction = (
        "Translate to clear English. Output ONLY the translation."
        if src != "hinglish"
        else "Translate Hinglish to clear English. Output ONLY the translation."
    )
    return groq_chat([
        {"role": "system", "content": "You are a professional translator."},
        {"role": "user", "content": f"{instruction}\n\n{text}"}
    ])

def translate_from_english(text: str, tgt: str) -> str:
    if tgt == "en":
        return text
    instruction = (
        "Translate to Hinglish (Hindi in English letters). Output ONLY the translation."
        if tgt == "hinglish"
        else f"Translate to {tgt}. Output ONLY the translation."
    )
    return groq_chat([
        {"role": "system", "content": "You are a professional translator."},
        {"role": "user", "content": f"{instruction}\n\n{text}"}
    ])

# =========================================================
# ROUTER
# =========================================================

def route_query(text: str) -> str:
    return groq_chat([{
        "role": "user",
        "content": f"""
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
{text}

Answer ONLY the category name.
"""
    }]).lower()

# =========================================================
# RAG
# =========================================================

def rag_answer(query: str, history: list) -> str:
    docs = retriever.invoke(query)
    if not docs:
        return (
            "I may not have detailed information on this yet. "
            "Please consider consulting a healthcare professional."
        )

    context = "\n\n".join(d.page_content for d in docs)

    prompt = ChatPromptTemplate.from_template("""
You are Aurora, a calm and professional women’s healthcare assistant.

Context:
{context}

Recent conversation:
{history}

Question:
{question}

Rules:
- Use ONLY the context
- Do NOT diagnose
- Maintain a respectful, reassuring tone
""")

    formatted = prompt.format(
        context=context,
        history="\n".join(f"{m['role']}: {m['content']}" for m in history[-6:]),
        question=query
    )

    return groq_chat([
        {"role": "system", "content": "You are Aurora."},
        {"role": "user", "content": formatted}
    ], temperature=0.3)

# =========================================================
# LANGGRAPH STATE
# =========================================================

class AuroraState(TypedDict):
    user_input: str
    user_input_en: str
    language: str
    category: str
    answer_en: str
    final_answer: str
    history: List[dict]
    safety_flag: bool

# =========================================================
# LANGGRAPH NODES
# =========================================================

def n_translate_to_en(state: AuroraState):
    state["user_input_en"] = translate_to_english(
        state["user_input"], state["language"]
    )
    return state

def n_route(state: AuroraState):
    state["category"] = route_query(state["user_input_en"])
    state["safety_flag"] = any(
        k in state["user_input_en"].lower()
        for k in ["suicide", "self harm", "abuse", "violence"]
    )
    return state

def n_greeting(state: AuroraState):
    state["answer_en"] = (
        "Welcome back. How can I support you today?"
        if len(state["history"]) > 1
        else "Hello. How can I support your health today?"
    )
    return state

def n_out_of_scope(state: AuroraState):
    state["answer_en"] = (
        "I focus on women’s healthcare topics such as symptoms, hormones, "
        "mental wellbeing, pregnancy, and preventive care."
    )
    return state

def n_safety(state: AuroraState):
    state["answer_en"] = (
        "I’m really glad you reached out. Your safety matters.\n\n"
        "If you’re feeling at risk, please consider contacting local support services "
        "or a trusted person right now."
    )
    return state

def n_rag(state: AuroraState):
    state["answer_en"] = rag_answer(
        state["user_input_en"], state["history"]
    )
    return state

def n_translate_back(state: AuroraState):
    state["final_answer"] = translate_from_english(
        state["answer_en"], state["language"]
    )
    return state

# =========================================================
# BUILD GRAPH
# =========================================================

graph = StateGraph(AuroraState)

graph.add_node("translate_to_en", n_translate_to_en)
graph.add_node("route", n_route)
graph.add_node("greeting", n_greeting)
graph.add_node("out_of_scope", n_out_of_scope)
graph.add_node("safety", n_safety)
graph.add_node("rag", n_rag)
graph.add_node("translate_back", n_translate_back)

graph.set_entry_point("translate_to_en")
graph.add_edge("translate_to_en", "route")

graph.add_conditional_edges(
    "route",
    lambda s: "safety" if s["safety_flag"] else s["category"],
    {
        "greeting": "greeting",
        "out_of_scope": "out_of_scope",
        "daily_symptom_support": "rag",
        "holistic_wellness_lifestyle": "rag",
        "hormonal_life_stages": "rag",
        "mental_emotional_resilience": "rag",
        "preventive_care_screening": "rag",
        "safety_support_advocacy": "rag",
        "safety": "safety",
    }
)

for node in ["greeting", "out_of_scope", "rag", "safety"]:
    graph.add_edge(node, "translate_back")

graph.add_edge("translate_back", END)

aurora = graph.compile()

# =========================================================
# STREAMLIT UI
# =========================================================

st.set_page_config(page_title="Aurora 🌸", layout="wide")

c1, c2 = st.columns([0.82, 0.18])
with c1:
    st.title("🌸 Aurora – Women’s Healthcare Assistant")
with c2:
    selected_lang = st.selectbox(
        "Language",
        list(LANGUAGES.keys()),
        label_visibility="collapsed"
    )

lang_code = LANGUAGES[selected_lang]

if "history_en" not in st.session_state:
    st.session_state.history_en = [
        {"role": "system", "content": "You are Aurora."}
    ]

if "chat_en" not in st.session_state:
    st.session_state.chat_en = [
        {"role": "assistant", "content": "Hello. How can I support your health today?"}
    ]

for msg in st.session_state.chat_en:
    with st.chat_message(msg["role"]):
        st.markdown(translate_from_english(msg["content"], lang_code))

user_input = st.chat_input("Ask about women’s health...")

if user_input:
    with st.chat_message("user"):
        st.markdown(user_input)

    with st.chat_message("assistant"):
        placeholder = st.empty()
        placeholder.markdown("Answering…")

    result = aurora.invoke({
        "user_input": user_input,
        "language": lang_code,
        "history": st.session_state.history_en,
    })

    placeholder.empty()

    with st.chat_message("assistant"):
        st.markdown(result["final_answer"])

    st.session_state.chat_en.append(
        {"role": "user", "content": result["user_input_en"]}
    )
    st.session_state.chat_en.append(
        {"role": "assistant", "content": result["answer_en"]}
    )

    st.session_state.history_en.append(
        {"role": "user", "content": result["user_input_en"]}
    )
    st.session_state.history_en.append(
        {"role": "assistant", "content": result["answer_en"]}
    )

    st.rerun()
