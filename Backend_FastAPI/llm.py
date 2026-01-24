# Groq calls
import os
from groq import Groq

groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))

def groq_chat(messages, temperature=0.3) -> str:
    response = groq_client.chat.completions.create(
        model="llama-3.1-8b-instant",
        messages=messages,
        temperature=temperature
    )
    return response.choices[0].message.content.strip()
