from groq import Groq
import os
from .llm import groq_chat

groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))

def route_query(query: str) -> str:
    prompt = f"""
You are a strict classifier for a women's healthcare assistant.

Your task:
Classify the query into EXACTLY ONE category from the list below.

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

STRICT RULES:
- ANY math, arithmetic, numbers, calculations → out_of_scope
- ANY coding, programming, algorithms → out_of_scope
- ANY general knowledge not about women's health → out_of_scope
- hi, hello → greeting
- bye, goodbye, exit → farewell

Query:
{query}

Return ONLY the category name. No explanation.
"""
    return groq_chat(
        [{"role": "user", "content": prompt}],
        temperature=0.0
    ).strip().lower()
