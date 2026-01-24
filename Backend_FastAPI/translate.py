# Translation helpers

from .llm import groq_chat

def to_english(text: str, lang: str) -> str:
    if lang == "en":
        return text

    instruction = (
        "Translate to clear English. "
        "Do not explain. Output only the translation."
    )

    return groq_chat([
        {"role": "system", "content": "You are a translation engine."},
        {"role": "user", "content": f"{instruction}\n\n{text}"}
    ], temperature=0.0)


def from_english(text: str, lang: str) -> str:
    if lang == "en":
        return text

    if lang == "hinglish":
        instruction = "Translate to Hinglish (Hindi in English letters)."
    else:
        instruction = f"Translate to {lang}."

    return groq_chat([
        {"role": "system", "content": "You are a translation engine."},
        {"role": "user", "content": f"{instruction}\n\n{text}"}
    ], temperature=0.0)
