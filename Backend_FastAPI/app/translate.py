import logging
from dotenv import load_dotenv
from .llm import groq_chat

load_dotenv()
logger = logging.getLogger(__name__)

# Extended language metadata — matches Streamlit app
LANG_META: dict[str, dict] = {
    "hi":  {"name": "Hindi",              "script": "Devanagari"},
    "bn":  {"name": "Bengali",            "script": "Bengali"},
    "mr":  {"name": "Marathi",            "script": "Devanagari"},
    "ta":  {"name": "Tamil",              "script": "Tamil"},
    "te":  {"name": "Telugu",             "script": "Telugu"},
    "gu":  {"name": "Gujarati",           "script": "Gujarati"},
    "kn":  {"name": "Kannada",            "script": "Kannada"},
    "ml":  {"name": "Malayalam",          "script": "Malayalam"},
    "pa":  {"name": "Punjabi",            "script": "Gurmukhi"},
    "ur":  {"name": "Urdu",               "script": "Arabic"},
    "or":  {"name": "Odia",               "script": "Odia"},
    "as":  {"name": "Assamese",           "script": "Bengali-Assamese"},
    "ne":  {"name": "Nepali",             "script": "Devanagari"},
    "kok": {"name": "Konkani",            "script": "Devanagari"},
    "ks":  {"name": "Kashmiri",           "script": "Arabic"},
    "sd":  {"name": "Sindhi",             "script": "Arabic"},
    "mai": {"name": "Maithili",           "script": "Devanagari"},
    "sat": {"name": "Santali",            "script": "Ol Chiki"},
    "mni": {"name": "Manipuri (Meitei)",  "script": "Meitei Mayek"},
    "brx": {"name": "Bodo",              "script": "Devanagari"},
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


def _cache_key(text: str, lang_pair: str) -> str:
    return f"{lang_pair}:{hash(text)}"


def translate_to_english(text: str, src_lang: str, cache: dict | None = None) -> str | None:
    """Returns English translation or None if rate-limited."""
    if src_lang == "en":
        return text

    key = _cache_key(text, f"{src_lang}>en")
    if cache is not None and key in cache:
        return cache[key]

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

    result = groq_chat(
        [
            {"role": "system", "content": "You are a strict translation engine."},
            {"role": "user",   "content": f"{instruction}\n\n{text}"},
        ],
        temperature=0.0,
    )

    if result is None:
        return None  # rate limit — caller handles

    if cache is not None:
        cache[key] = result
    return result


def translate_from_english(text: str, tgt_lang: str, cache: dict | None = None) -> str:
    """Returns translated text. Falls back to English on rate limit."""
    if tgt_lang == "en":
        return text

    key = _cache_key(text, f"en>{tgt_lang}")
    if cache is not None and key in cache:
        return cache[key]

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
            "Translate the following text into the target language. "
            "Do not explain. Output ONLY the translation."
        )

    result = groq_chat(
        [
            {"role": "system", "content": "You are a professional translation engine."},
            {"role": "user",   "content": f"{instruction}\n\n{text}"},
        ],
        temperature=0.0,
    )

    if result is None:
        logger.warning("Rate limit during translation — returning English fallback")
        return text  # fallback so user still gets a response

    if cache is not None:
        cache[key] = result
    return result