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
    # block only real arithmetic expressions
    if MATH_PATTERN.search(query) and any(op in query for op in ['+', '-', '*', '/', '%']):
        return True

    # block programming / code
    if CODING_PATTERN.search(query):
        return True

    return False

def route_query(query: str) -> str:
    prompt = f"""
You are a routing assistant for a women's healthcare chatbot.

IMPORTANT:
If the query is related to:
- women’s body
- periods or menstruation
- hormones or life stages
- mental or emotional health
- lifestyle or wellness
- safety or support

DO NOT classify it as out_of_scope.

ONLY classify as out_of_scope if it is:
- mathematics or calculations
- programming or coding
- unrelated general knowledge

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

Query:
{query}

Return ONLY the category name.
"""
    return groq_chat(
        [{"role": "user", "content": prompt}],
        temperature=0.0
    ).strip().lower()
