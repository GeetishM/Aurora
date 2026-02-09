from groq import Groq
import os

from dotenv import load_dotenv
load_dotenv()

groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))

LANG_META = {
    "hi": {"name": "Hindi", "script": "Devanagari"},
    "bn": {"name": "Bengali", "script": "Bengali"},
    "mr": {"name": "Marathi", "script": "Devanagari"},
    "ta": {"name": "Tamil", "script": "Tamil"},
    "te": {"name": "Telugu", "script": "Telugu"},
    "gu": {"name": "Gujarati", "script": "Gujarati"},
    "kn": {"name": "Kannada", "script": "Kannada"},
    "ml": {"name": "Malayalam", "script": "Malayalam"},
    "pa": {"name": "Punjabi", "script": "Gurmukhi"},
    "ur": {"name": "Urdu", "script": "Arabic"},
    "or": {"name": "Odia", "script": "Odia"},
}

def groq_chat(prompt: str) -> str:
    res = groq_client.chat.completions.create(
        model="llama-3.1-8b-instant",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.0
    )
    return res.choices[0].message.content.strip()

def translate_to_english(text: str, src_lang: str) -> str:
    if src_lang == "en":
        return text

    if src_lang == "hinglish":
        prompt = "Translate Hinglish to clear English. Only output translation.\n\n" + text
    else:
        prompt = "Translate to clear English. Only output translation.\n\n" + text

    return groq_chat(prompt)

def translate_from_english(text: str, tgt_lang: str) -> str:
    if tgt_lang == "en":
        return text

    if tgt_lang == "hinglish":
        prompt = "Translate to Hinglish (Hindi in English letters). Only output translation.\n\n" + text
    elif tgt_lang in LANG_META:
        meta = LANG_META[tgt_lang]
        prompt = (
            f"Translate to {meta['name']} using {meta['script']} script. "
            f"Only output translation.\n\n{text}"
        )
    else:
        prompt = "Translate to target language. Only output translation.\n\n" + text

    return groq_chat(prompt)
