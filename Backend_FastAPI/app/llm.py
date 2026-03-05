import os
import re
import logging
from groq import Groq, RateLimitError, APIStatusError
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))

# ── Helpers ────────────────────────────────────────────────────────────────────

def parse_retry_seconds(error: RateLimitError) -> str:
    """Extract the retry-after hint from the Groq error message."""
    try:
        match = re.search(
            r"(?:try again in|retry after)\s+([\d.]+\s*\w+)",
            str(error),
            re.IGNORECASE,
        )
        if match:
            return match.group(1)
    except Exception:
        pass
    return "a moment"


# ── Non-streaming ──────────────────────────────────────────────────────────────

def groq_chat(messages: list, temperature: float = 0.3) -> str | None:
    """
    Returns the response string.
    Returns None on rate limit so callers can handle it gracefully.
    """
    try:
        response = groq_client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=messages,
            temperature=temperature,
            stream=False,
        )
        return response.choices[0].message.content.strip()

    except RateLimitError as e:
        logger.warning("Groq rate limit hit (non-stream): %s", e)
        return None   # caller checks for None

    except APIStatusError as e:
        logger.error("Groq API error (non-stream): %s", e)
        return None


# ── Streaming ──────────────────────────────────────────────────────────────────

def groq_chat_stream(messages: list, temperature: float = 0.3):
    """
    Yields text tokens.
    On rate limit, yields a single user-friendly message token so the
    caller's streaming loop still works without extra error handling.
    """
    try:
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

    except RateLimitError as e:
        retry_hint = parse_retry_seconds(e)
        logger.warning("Groq rate limit hit (stream): %s", e)
        yield (
            f"\n\n⚠️ I'm receiving a lot of questions right now — please wait "
            f"{retry_hint} and ask again. Your question hasn't been lost! 🌸"
        )

    except APIStatusError as e:
        logger.error("Groq API error (stream): %s", e)
        yield "\n\n❌ Something went wrong on my end. Please try sending your message again. 💙"