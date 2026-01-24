# Query classification
from .llm import groq_chat

def route_query(query: str) -> str:
    prompt = f"""
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
{query}

Answer ONLY the category name.
"""
    return groq_chat(
        [{"role": "user", "content": prompt}],
        temperature=0.0
    ).lower()
