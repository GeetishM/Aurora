import re
import logging
from .llm import groq_chat

logger = logging.getLogger(__name__)

# ── Hard block — pure arithmetic only ─────────────────────────────────────────
MATH_PATTERN = re.compile(
    r"\b(\d+\s*[\+\-\*/%]\s*\d+|\d+\s*(plus|minus|times|multiply|divide|mod)\s*\d+)\b",
    re.IGNORECASE,
)

# ── Hard block — unambiguous code only ────────────────────────────────────────
# ⚠️  DO NOT add common English words like: for, if, while, return, else,
#     class, print, import — they all appear in normal health questions.
#     e.g. "Tips FOR managing pain", "IF you have symptoms", "RETURN to normal"
#
# Only block when there is clear, unambiguous programming syntax:
CODING_PATTERN = re.compile(
    r"\b(python|javascript|typescript|html|css|flutter|dart|sql)\b"  # unambiguous language names
    r"|[{};]"                                                          # code structure symbols { } ;
    r"|\bdef\s+\w+\s*\("                                              # def function_name(
    r"|\bimport\s+[a-zA-Z_]"                                          # import something
    r"|\bconsole\.(log|error|warn)\b"                                 # console.log
    r"|\bfunction\s+\w+\s*\("                                         # function name(
    r"|\bclass\s+[A-Z]\w+\s*[{(:]"                                    # class ClassName( or {
    r"|\bstd::"                                                        # C++ std::
    r"|\b#include\b",                                                  # C/C++ include
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
    # Only block real arithmetic expressions (number OP number)
    if MATH_PATTERN.search(query) and any(op in query for op in ['+', '-', '*', '/', '%']):
        return True
    # Only block clear programming syntax
    if CODING_PATTERN.search(query):
        return True
    return False


def route_query(query: str) -> str:
    """
    Returns a category string.
    Returns 'rate_limited' if Groq quota is hit so the caller can respond gracefully.
    """
    prompt = f"""
You are a routing assistant for a women's healthcare chatbot.

Classify the query into ONE of these categories:
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
- bye, goodbye, see you → farewell
- hi, hello, hey → greeting
- ANYTHING related to: women's body, periods, menstruation, cramps, pain,
  hormones, pregnancy, fertility, menopause, mental health, emotions, stress,
  anxiety, lifestyle, nutrition, exercise, sleep, wellness, safety, abuse,
  healthcare, symptoms, or any medical concern → use the most relevant health category
- ONLY use out_of_scope for: pure mathematics, programming/coding questions,
  or completely unrelated topics like sports scores or geography

Query: {query}

Return ONLY the category name. Nothing else.
"""
    response = groq_chat([{"role": "user", "content": prompt}], temperature=0.0)

    if response is None:
        return "rate_limited"

    response = response.strip().lower()
    return response if response in VALID_CATEGORIES else "out_of_scope"