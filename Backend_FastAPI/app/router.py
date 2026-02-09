import re
from .llm import groq_chat

MATH_PATTERN = re.compile(
    r"\b(\d+\s*[\+\-\*/%]\s*\d+|\d+\s*(plus|minus|times|multiply|divide|mod)\s*\d+)\b",
    re.IGNORECASE
)

CODING_PATTERN = re.compile(
    r"\b("
    r"python|java|c\+\+|javascript|typescript|sql|html|css|flutter|dart|"
    r"function|class|def|return|for|while|if|else|import|print|console"
    r")\b|[{}();<>]",
    re.IGNORECASE
)

def is_hard_out_of_scope(query: str) -> bool:
    return bool(
        MATH_PATTERN.search(query) or CODING_PATTERN.search(query)
    )

def route_query(query: str) -> str:
    if is_hard_out_of_scope(query):
        return "out_of_scope"

    prompt = f"""
You are a strict classifier for a women's healthcare assistant.

Allowed categories:
greeting
farewell
daily_symptom_support
holistic_wellness_lifestyle
hormonal_life_stages
mental_emotional_resilience
preventive_care_screening
safety_support_advocacy
out_of_scope

Query:
{query}

Return ONLY the category name.
"""
    return groq_chat(
        [{"role": "user", "content": prompt}],
        temperature=0.0
    ).strip().lower()
