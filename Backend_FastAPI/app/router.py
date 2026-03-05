import re
import logging
from .llm import groq_chat

logger = logging.getLogger(__name__)

# Hard-block patterns (no LLM needed)
MATH_PATTERN = re.compile(
    r"\b(\d+\s*[\+\-\*/%]\s*\d+|\d+\s*(plus|minus|times|multiply|divide|mod)\s*\d+)\b",
    re.IGNORECASE,
)
CODING_PATTERN = re.compile(
    r"\b(python|java|c\+\+|javascript|typescript|sql|html|css|flutter|dart|"
    r"function|class|def|return|for|while|if|else|import|print|console)\b|[{}();<>]",
    re.IGNORECASE,
)

VALID_CATEGORIES = {
    "greeting", "farewell",
    "daily_symptom_support", "holistic_wellness_lifestyle",
    "hormonal_life_stages", "mental_emotional_resilience",
    "preventive_care_screening", "safety_support_advocacy",
    "out_of_scope",
}


def is_hard_out_of_scope(query: str) -> bool:
    if MATH_PATTERN.search(query) and any(op in query for op in ['+', '-', '*', '/', '%']):
        return True
    if CODING_PATTERN.search(query):
        return True
    return False


def route_query(query: str) -> str:
    """
    Returns a category string.
    Returns 'rate_limited' if Groq quota is hit so the caller can respond gracefully.
    """
    prompt = f"""
Classify this women's healthcare query into ONE category.

Categories:
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
- hi, hello, hey → greeting
- Anything related to women's body, periods, hormones, mental health, lifestyle, wellness, safety → use the most relevant health category
- Mathematics, programming, coding, unrelated general knowledge → out_of_scope

Query:
{query}

Return ONLY the category name. Nothing else.
"""
    response = groq_chat([{"role": "user", "content": prompt}], temperature=0.0)

    if response is None:
        return "rate_limited"

    response = response.strip().lower()
    return response if response in VALID_CATEGORIES else "out_of_scope"