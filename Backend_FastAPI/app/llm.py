import os
from groq import Groq
from dotenv import load_dotenv
from httpx import stream

load_dotenv()

groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))

def groq_chat_stream(messages, temperature=0.3):
    stream = groq_client.chat.completions.create(
        model="llama-3.1-8b-instant",
        messages=messages,
        temperature=temperature,
        stream=True
    )

    for chunk in stream:
        delta = chunk.choices[0].delta.content
        if delta:
            yield delta
