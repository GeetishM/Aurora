"""
Humanized response banks — mirrors the Streamlit app's tone.
All replies are warm, personal, and non-clinical.
"""
import random

# ── Greetings ─────────────────────────────────────────────────────────────────

FIRST_GREETINGS = [
    "Hi there! I'm Aurora 🌸 I'm here to support you with any women's health questions you have. What's on your mind today?",
    "Hello! Welcome — I'm Aurora, your women's health companion. Feel free to ask me anything, I'm here to help. 💙",
    "Hi! I'm so glad you're here. I'm Aurora, and I'm here to help you navigate any health questions or concerns. What would you like to talk about?",
    "Hello and welcome! I'm Aurora 🌸 Think of me as a knowledgeable friend who's always here to talk through your health questions. How can I support you today?",
    "Hi there! I'm Aurora — a women's health assistant here to provide a safe, supportive space for your questions. What can I help you with?",
]

RETURN_GREETINGS = [
    "Welcome back! 🌸 It's good to hear from you again. What's on your mind today?",
    "Hey, good to see you again! How have you been? What can I help you with today?",
    "Welcome back! I'm here whenever you need me. What would you like to talk about?",
    "Hello again! 😊 I'm glad you came back. What health questions can I help you with today?",
    "Good to have you back! How are you feeling? What can I support you with today?",
]

# ── Farewells ─────────────────────────────────────────────────────────────────

FAREWELLS = [
    "Take care of yourself — you deserve it. 🌸 I'll be right here whenever you need me.",
    "Goodbye for now! Remember, your health matters and so do you. Come back anytime. 💙",
    "Take care! It was lovely chatting with you. Don't hesitate to reach out whenever you need support. 🌸",
    "Wishing you good health and peace of mind. See you next time! 😊",
    "Bye for now! Remember to be kind to yourself. I'm always here if you have more questions. 💙",
    "Take care and stay well! It's been a pleasure. Come back anytime — I'm always here for you. 🌸",
]

# ── Out of scope ──────────────────────────────────────────────────────────────

OUT_OF_SCOPE = [
    "That's a little outside the area I'm built to support, but I genuinely want to help you. "
    "If there's anything on your mind related to your health and wellbeing as a woman, please do ask — I'm all ears. 🌸",
    "I'm best at supporting questions around women's health and wellness, so I may not be the right fit for that one. "
    "But if something health-related is weighing on you, I'm right here and happy to help. 💙",
    "That's not quite in my area of expertise, but your wellbeing is what matters most to me. "
    "If you have any questions about your health — big or small — please feel free to share. I'm here for you. 🌸",
    "I'm a little limited outside of women's health topics, but I never want you to feel like you have nowhere to turn. "
    "Is there a health question or concern I can help you with instead? 💙",
    "That one's a bit beyond what I'm designed for — I'd hate to give you an unhelpful answer! "
    "But if there's anything women's health-related on your mind, I'm genuinely here to support you. 🌸",
]

# ── No context found ──────────────────────────────────────────────────────────

NO_CONTEXT = [
    "I want to make sure I give you accurate information, and I don't have enough detail on that specific topic right now. "
    "For anything that feels urgent or medical, please do reach out to a healthcare professional — "
    "they'll be able to give you the personalised support you deserve. 💙",
    "That's a great question, and I want to give you a really good answer. "
    "I don't have enough information in my knowledge base right now to respond well, "
    "but a healthcare provider would be the best person to guide you on this. 🌸",
]

# ── Rate limited ──────────────────────────────────────────────────────────────

RATE_LIMITED = (
    "I'm receiving a lot of questions right now and need just a moment to catch up. "
    "Please try again in about 30 seconds — I promise I'll be right here! 🌸"
)


def random_greeting(returning: bool = False) -> str:
    return random.choice(RETURN_GREETINGS if returning else FIRST_GREETINGS)

def random_farewell() -> str:
    return random.choice(FAREWELLS)

def random_out_of_scope() -> str:
    return random.choice(OUT_OF_SCOPE)

def random_no_context() -> str:
    return random.choice(NO_CONTEXT)