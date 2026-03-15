
# Aurora 🌸
AI-Powered Women's Healthcare Chatbot

## Table of Contents📋
 
- [About](#about)
- [Project Versions](#project-versions)
- [Features](#features)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Evaluation Results](#evaluation-results)
- [Screenshots](#screenshots)
- [Supported Languages](#supported-languages)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Running the App](#running-the-app)
- [API Reference](#api-reference)
- [Query Categories](#query-categories)
---

## About

**Aurora** is a RAG-based multilingual conversational AI system designed to provide accessible, accurate and empathetic women's healthcare guidance. Built as a capstone project, Aurora combines a Flutter mobile frontend with a FastAPI backend powered by Groq's LLaMA 3.1, Qdrant vector database and Groq Whisper for voice transcription.
 
Aurora speaks like a caring, informed friend never clinical or cold and supports **29 languages including 22 Indian regional languages**, making healthcare information accessible to millions of underserved women.


## Badges

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Groq](https://img.shields.io/badge/Groq-LLaMA%203.1-F55036?logo=groq)](https://groq.com)
[![Qdrant](https://img.shields.io/badge/Qdrant-Vector%20DB-DC244C)](https://qdrant.tech)
[![Ollama](https://img.shields.io/badge/Ollama-mxbai--embed--large-black)](https://ollama.com)
[![Languages](https://img.shields.io/badge/Languages-29-brightgreen)](#supported-languages)

*A warm, knowledgeable AI companion for women's health — available in 29 languages*
## Project Versions

 
Aurora was developed in two phases:
 
### Phase 1 — Streamlit Web App (`Streamlit_Web_App/`)🖥️
 
The initial prototype built to validate the RAG pipeline and multilingual capabilities. A web-based chat interface built with Streamlit that served as the foundation for the full system used to run RAGAS evaluations, test query routing, and fine-tune the RAG pipeline before mobile development began.
 
**Run the Streamlit app:**
```bash
cd Streamlit_Web_App
streamlit run app.py
```
 
### Phase 2 — Flutter Mobile App + FastAPI Backend📱
 
The production version — a full Flutter mobile app with real-time WebSocket streaming, voice input, dark/light theme, persistent chat history, and a FastAPI backend decoupled from the frontend.
 
---
## Features
 
- 🤖 **RAG Pipeline:** Retrieval-Augmented Generation with MMR for diverse, accurate answers
- 🎙️ **Voice Input:** Groq Whisper transcription for hands-free interaction
- 🌍 **29 Languages:** Full support for Indian regional and international languages
- ⚡ **Real-time Streaming:** Token-by-token WebSocket streaming responses
- 🧠 **Smart Routing:** LLM-based query classification into 8 health categories
- 📝 **Conversation Memory:** Automatic summarisation for long conversations
- 🌓 **Dark / Light Theme:** Persistent theme with Aurora brand colors
- 💬 **Chat History:** Persistent local storage with Hive
- 🔄 **Query Rewriting:** Context-aware search optimisation for better retrieval



## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Mobile App                      │
│   Chat UI  ─  Voice Input  ─  Language Picker  ─  History   │
└─────────────────────┬───────────────────────────────────────┘
                      │ WebSocket (streaming) / HTTP
┌─────────────────────▼───────────────────────────────────────┐
│                    FastAPI Backend                          │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐   │
│  │Translate │  │  Router  │  │   RAG    │  │ Transcribe │   │
│  │(Groq LLM)│  │(Groq LLM)│  │ Pipeline │  │  (Whisper) │   │
│  └──────────┘  └──────────┘  └────┬─────┘  └────────────┘   │
│                                   │                         │
│                         ┌─────────▼──────────┐              │
│                         │   Qdrant Vector DB │              │
│                         │  mxbai-embed-large │              │
│                         │   (via Ollama)     │              │
│                         └────────────────────┘              │
└─────────────────────────────────────────────────────────────┘
```

**Request flow:**
1. User sends message (text or voice)
2. Translate to English (if needed)
3. Hard block check (regex) → soft route (LLM)
4. Query rewriting for better retrieval
5. MMR retrieval from Qdrant
6. LLaMA 3.1 generates streaming response
7. Translate back to user's language
8. Stream tokens via WebSocket to Flutter
---
## Tech Stack

| Layer | Technology |
|---|---|
| Mobile Frontend | Flutter (Dart) |
| Web Prototype | Streamlit (Python) |
| Backend API | FastAPI (Python) |
| LLM | Groq: LLaMA 3.1 8B Instant |
| Embeddings | Ollama: mxbai-embed-large |
| Vector Database | Qdrant (local) |
| Voice Transcription | Groq Whisper Large v3 Turbo |
| Real-time Communication | WebSockets |
| Local Storage | Hive (Flutter) |
| RAG Evaluation | RAGAS Framework |
 
---
## Evaluation Results
Evaluated using the **RAGAS framework** across 15 women's health queries covering PCOS, menopause, pregnancy, UTI, anemia, endometriosis, mental health, and more.
 
| Metric | Score |
|---|---|
| ✅ Answer Relevancy | **93.7%** |
| ✅ Context Precision | **89.8%** |
| ⚠️ Faithfulness | **78.3%** |
| ⚠️ Context Recall | **72.2%** |
 
> Full evaluation results available in `Streamlit_Web_App/eval_results.csv`
 
------

## Screenshots

### 🖥️ Streamlit Web App
| Chat Interface | Multilingual Support |
|---|---|
| ![Streamlit Chat](assets/streamlit_chat.png) | ![Streamlit Lang](assets/streamlit_lang.png) |

### 📱 Flutter Mobile App

| Dark Home | Light Home | Topic Grid | Category Questions |
|---|---|---|---|
| ![Dark Home](assets/flutter_home_dark.png) | ![Light Home](assets/flutter_home_light.png) | ![Topics](assets/flutter_topics.png) | ![Category](assets/flutter_category.png) |

| AI Response | Voice Recording | Speech to Text | Language Picker |
|---|---|---|---|
| ![Chat](assets/flutter_chat.png) | ![Recording](assets/flutter_recording.png) | ![Transcribing](assets/flutter_transcribing.png) | ![Languages](assets/flutter_languages.png) |

---

## Supported Languages

**22 Indian Regional Languages**
 
| Code | Language | Script |
|---|---|---|
| hi | Hindi | Devanagari |
| bn | Bengali | Bengali |
| mr | Marathi | Devanagari |
| ta | Tamil | Tamil |
| te | Telugu | Telugu |
| gu | Gujarati | Gujarati |
| kn | Kannada | Kannada |
| ml | Malayalam | Malayalam |
| pa | Punjabi | Gurmukhi |
| ur | Urdu | Arabic |
| or | Odia | Odia |
| as | Assamese | Bengali-Assamese |
| ne | Nepali | Devanagari |
| kok | Konkani | Devanagari |
| ks | Kashmiri | Arabic |
| sd | Sindhi | Arabic |
| mai | Maithili | Devanagari |
| sat | Santali | Ol Chiki |
| mni | Manipuri | Meitei Mayek |
| brx | Bodo | Devanagari |
| doi | Dogri | Devanagari |
| hinglish | Hinglish | Latin |

 
**International Languages**
 
Spanish, French, German, Arabic, Portuguese, Indonesian, Japanese, Korean, Chinese

---
## Project Structure
 
```
Aurora/
├── Streamlit_Web_App/           # Phase 1 — Web prototype
│   ├── app.py                   # Streamlit chat interface
│   ├── ingest.py                # Document ingestion script
│   ├── evaluate.py              # RAGAS evaluation script
│   ├── eval_results.csv         # Evaluation results
│   ├── qdrant_db/               # Local Qdrant vector DB (not committed)
│   ├── Aurora_Datasets/         # Medical documents (not committed)
│   └── .env                     # API keys (not committed)
│
├── Backend_FastAPI/             # Phase 2 — Production backend
│   ├── app/
│   │   ├── main.py              # FastAPI app, CORS, routes
│   │   ├── websocket.py         # WebSocket handler + streaming
│   │   ├── rag.py               # RAG pipeline + query rewriting
│   │   ├── router.py            # Query classification
│   │   ├── translate.py         # Bidirectional translation
│   │   ├── llm.py               # Groq LLM wrapper
│   │   ├── embeddings.py        # Ollama embeddings
│   │   ├── qdrant_store.py      # Vector store + MMR retriever
│   │   ├── response_banks.py    # Humanized response templates
│   │   ├── models.py            # Pydantic models
│   │   └── routers/
│   │       └── transcribe.py    # Groq Whisper endpoint
│   ├── Aurora_Datasets/         # Medical documents (not committed)
│   ├── qdrant_db/               # Local Qdrant vector DB (not committed)
│   ├── ingest.py                # Document chunking + ingestion
│   ├── aurora.bat               # One-click backend launcher (Windows)
│   └── .env                     # API keys (not committed)
│
├── frontend_flutter/            # Phase 2 — Mobile frontend
│   └── lib/
│       ├── main.dart
│       ├── core/
│       │   ├── config/server_config.dart
│       │   └── websocket/ws_service.dart
│       ├── features/chat/chat_screen.dart
│       └── state/chat_controller.dart
│
├── ML_Datasets/                 # Women's health ML datasets (not committed)
├── ml_models/                   # Experimental ML models (in progress)
└── requirements.txt
```
 
> ⚠️ **Note:** `Aurora_Datasets/`, `ML_Datasets/`, `qdrant_db/`, and all `.env` files are excluded via `.gitignore`. You will need to provide your own datasets and API keys to run the project.
 
---
## Getting Started
### Prerequisites
 
- Python 3.10+
- Flutter 3.x
- [Ollama](https://ollama.com/download) installed and running
- [Groq API key](https://console.groq.com) (free)
 
### 1. Clone the repository
 
```bash
git clone https://github.com/GeetishM/Aurora.git
cd Aurora
```
 
### 2. Create your `.env` files
 
Both `Streamlit_Web_App/` and `Backend_FastAPI/` need a `.env` file:
 
```env
GROQ_API_KEY=your_groq_api_key_here
```
 
### 3. Install Python dependencies
 
```bash
pip install -r requirements.txt
```
 
### 4. Pull the embedding model
 
```bash
ollama pull mxbai-embed-large
```
 
### 5. Add medical documents and ingest
 
Place your medical PDF/text documents into `Aurora_Datasets/`, then run:
 
```bash
# For Streamlit
cd Streamlit_Web_App && python ingest.py
 
# For FastAPI
cd Backend_FastAPI && python ingest.py
```
 
### 6. Flutter setup
 
```bash
cd frontend_flutter
flutter pub get
```
 
---
 
## Running the App
 
### Option A — Streamlit Web App (quickest)
 
```bash
cd Streamlit_Web_App
streamlit run app.py
```
 
### Option B — Flutter Mobile App
 
**Terminal 1 — Start Ollama:**
```bash
ollama serve
```
 
**Terminal 2 — Start FastAPI backend:**
```bash
cd Backend_FastAPI
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
 
**Terminal 3 — Start Flutter app:**
```bash
cd frontend_flutter
flutter run
```
 
---
## API Reference

| Endpoint | Method | Description |
|---|---|---|
| `/` | GET | Health check |
| `/ws/chat` | WebSocket | Streaming chat |
| `/api/transcribe` | POST | Audio → text (Whisper) |
| `/translate` | POST | Text translation |
 
### WebSocket Message Format
 
**Send:**
```json
{
  "message": "What are symptoms of PCOS?",
  "language": "hi"
}
```
 
**Receive (streaming):**
```json
{ "type": "chunk", "text": "PCOS के लक्षणों" }
{ "type": "final", "text": "...", "sources": [...] }
```
 
---
## Query Categories

Aurora routes queries into 8 health categories:
 
| Category | Examples |
|---|---|
| `daily_symptom_support` | Cramps, headaches, fatigue |
| `hormonal_life_stages` | Menopause, perimenopause, puberty |
| `holistic_wellness_lifestyle` | Nutrition, exercise, sleep |
| `mental_emotional_resilience` | Anxiety, depression, stress |
| `preventive_care_screening` | Mammograms, Pap smears |
| `safety_support_advocacy` | Domestic violence resources |
| `greeting` / `farewell` | Conversational turns |
 
---
## Credits & Collaborators
This project is made possible by the efforts of:
- [Geetish Mahato](https://github.com/GeetishM) (That is me 😊)
- [Anamika Dey](https://github.com/anamikadey099)
- [Pragya Kumar](https://github.com/Pragya-Kumar)

Made with 🌸 for women's health accessibility
