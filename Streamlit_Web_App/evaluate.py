"""
evaluate.py  —  Aurora RAG Pipeline Evaluation using RAGAS
===========================================================

Metrics:
  • Faithfulness                  Are all claims grounded in retrieved context?
  • Answer Relevancy              Is the answer actually relevant to the question?
  • Context Precision             Are retrieved chunks ranked for signal / noise?
  • Context Recall                Was all needed information retrieved?

Usage:
  python evaluate.py                   # run all 15 questions
  python evaluate.py --n 5             # quick smoke-test (first 5 questions)
  python evaluate.py --output my.csv   # custom output CSV

Requirements:
  ragas>=0.2.0  langchain-groq  langchain-ollama  langchain-qdrant  python-dotenv  pandas
"""

import os
import time
import argparse
import warnings
from pathlib import Path
from typing import Any

# Suppress all deprecation noise (ragas wrappers, etc.)
warnings.filterwarnings("ignore", category=DeprecationWarning)

import pandas as pd
from dotenv import load_dotenv
from groq import Groq
from langchain_groq import ChatGroq
from langchain_ollama import OllamaEmbeddings
from langchain_qdrant import QdrantVectorStore
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.messages import BaseMessage
from qdrant_client import QdrantClient

# ── RAGAS — use ragas.metrics (supports LangchainLLMWrapper) ───────────────
from ragas.metrics import (
    Faithfulness,
    ResponseRelevancy,
    LLMContextPrecisionWithoutReference,
    LLMContextRecall,
)
from ragas import SingleTurnSample, EvaluationDataset, evaluate, RunConfig
from ragas.llms import LangchainLLMWrapper
from ragas.embeddings import LangchainEmbeddingsWrapper


# ═══════════════════════════════════════════════════════════════════════════
#  CONFIG
# ═══════════════════════════════════════════════════════════════════════════

load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
assert GROQ_API_KEY, "❌ GROQ_API_KEY missing from .env"

QDRANT_PATH     = "qdrant_db"
COLLECTION_NAME = "aurora_womens_health"
GROQ_MODEL      = "llama-3.1-8b-instant"


# ═══════════════════════════════════════════════════════════════════════════
#  GROQ-SAFE LLM WRAPPER
#
#  RAGAS calls the LLM with n > 1 for some metrics.
#  Groq rejects n > 1 with a 400 BadRequestError.
#  This subclass strips 'n' from every call before it hits the API.
# ═══════════════════════════════════════════════════════════════════════════

class GroqSafeLLM(ChatGroq):
    def _generate(self, messages: list[BaseMessage], stop=None, run_manager=None, **kwargs: Any):
        kwargs.pop("n", None)
        return super()._generate(messages, stop=stop, run_manager=run_manager, **kwargs)

    async def _agenerate(self, messages: list[BaseMessage], stop=None, run_manager=None, **kwargs: Any):
        kwargs.pop("n", None)
        return await super()._agenerate(messages, stop=stop, run_manager=run_manager, **kwargs)


# ═══════════════════════════════════════════════════════════════════════════
#  VECTOR STORE  (mirrors app.py)
# ═══════════════════════════════════════════════════════════════════════════

print("🔌 Loading embeddings & Qdrant vector store...")

_embeddings    = OllamaEmbeddings(model="mxbai-embed-large")
_qdrant_dir    = Path(__file__).resolve().parent / QDRANT_PATH
_qdrant_client = QdrantClient(path=str(_qdrant_dir))

vectorstore = QdrantVectorStore(
    client          = _qdrant_client,
    collection_name = COLLECTION_NAME,
    embedding       = _embeddings,
)
retriever = vectorstore.as_retriever(search_kwargs={"k": 4})


# ═══════════════════════════════════════════════════════════════════════════
#  RAGAS EVALUATOR
# ═══════════════════════════════════════════════════════════════════════════

print("🤖 Initialising RAGAS evaluator (Groq + Ollama embeddings)...")

_chat_llm = GroqSafeLLM(
    model           = GROQ_MODEL,
    api_key         = GROQ_API_KEY,
    temperature     = 0.0,
    request_timeout = 120,
    max_retries     = 3,
)

evaluator_llm        = LangchainLLMWrapper(_chat_llm)
evaluator_embeddings = LangchainEmbeddingsWrapper(_embeddings)


# ═══════════════════════════════════════════════════════════════════════════
#  ANSWER GENERATION  (same RAG pipeline as app.py)
# ═══════════════════════════════════════════════════════════════════════════

_groq_raw = Groq(api_key=GROQ_API_KEY)

_RAG_PROMPT = ChatPromptTemplate.from_template("""
You are Aurora, a professional women's healthcare assistant.

Context:
{context}

User question:
{question}

Rules:
- Use ONLY the provided context
- Do NOT diagnose
- Calm, respectful, supportive tone
""")


def generate_answer(question: str) -> tuple[str, list[str]]:
    docs = retriever.invoke(question)
    if not docs:
        return "I may not have detailed information on this topic yet.", []

    context      = "\n\n".join(d.page_content for d in docs)
    context_list = [d.page_content for d in docs]

    formatted = _RAG_PROMPT.format(context=context, question=question)
    resp = _groq_raw.chat.completions.create(
        model    = GROQ_MODEL,
        messages = [
            {"role": "system", "content": "You are Aurora, a women's healthcare assistant."},
            {"role": "user",   "content": formatted},
        ],
        temperature=0.3,
    )
    return resp.choices[0].message.content.strip(), context_list


# ═══════════════════════════════════════════════════════════════════════════
#  TEST DATASET  —  15 questions across all 8 Aurora categories
# ═══════════════════════════════════════════════════════════════════════════

TEST_DATASET: list[tuple[str, str]] = [

    # daily_symptom_support
    ("What are the common symptoms of PCOS?",
     "Common PCOS symptoms include irregular or absent periods, excess androgen levels "
     "causing acne, oily skin or hirsutism, polycystic ovaries on ultrasound, weight "
     "gain, thinning hair, and difficulty getting pregnant."),

    ("What are the signs of iron deficiency anemia in women?",
     "Signs include persistent fatigue, weakness, pale skin, shortness of breath, "
     "dizziness, cold hands and feet, brittle nails, and unusual cravings for ice or dirt."),

    ("What symptoms indicate a urinary tract infection (UTI)?",
     "UTI symptoms include a burning sensation when urinating, frequent and urgent need "
     "to urinate, cloudy or strong-smelling urine, pelvic pain, and sometimes blood in urine."),

    ("What is endometriosis and what symptoms does it cause?",
     "Endometriosis is a condition where tissue similar to the uterine lining grows outside "
     "the uterus. It causes severe pelvic pain, painful periods, pain during intercourse, "
     "heavy bleeding, and can lead to infertility."),

    # hormonal_life_stages
    ("What are the typical symptoms of menopause?",
     "Menopause symptoms include irregular then absent periods, hot flashes, night sweats, "
     "vaginal dryness, sleep disturbances, mood changes, reduced libido, and bone density loss."),

    ("What physical changes happen during the first trimester of pregnancy?",
     "In the first trimester the embryo's major organs begin forming. The woman may experience "
     "nausea and vomiting, extreme fatigue, breast tenderness, frequent urination, food "
     "aversions or cravings, and light implantation bleeding."),

    ("What is perimenopause and at what age does it typically begin?",
     "Perimenopause is the transition leading up to menopause, typically starting in a "
     "woman's early-to-mid 40s, characterised by irregular periods, hot flashes, and mood swings."),

    # holistic_wellness_lifestyle
    ("How does cycle syncing support a woman's fitness routine?",
     "Cycle syncing matches exercise intensity to cycle phases: higher-intensity workouts "
     "during follicular and ovulatory phases, and lower-intensity activities like yoga "
     "during the luteal and menstrual phases."),

    ("What nutritional deficiencies are most common in women?",
     "Women commonly lack iron, calcium, vitamin D, folate, magnesium, iodine, and "
     "omega-3 fatty acids, affecting bone density, reproductive health, and energy."),

    # mental_emotional_resilience
    ("What are the symptoms of postpartum depression?",
     "Postpartum depression symptoms include persistent sadness, severe mood swings, "
     "difficulty bonding with the baby, withdrawal from others, sleep and appetite changes, "
     "overwhelming fatigue, and in severe cases thoughts of self-harm."),

    ("What are effective stress management strategies for women?",
     "Effective strategies include regular exercise, mindfulness meditation, consistent sleep, "
     "social support, journalling, CBT, reducing caffeine, setting healthy boundaries, "
     "and professional counselling when needed."),

    # preventive_care_screening
    ("When should women start getting mammograms for breast cancer screening?",
     "Average-risk women should begin annual or biennial mammograms at age 40-50. Women "
     "with higher risk may need to start earlier and discuss timing with their doctor."),

    ("What contraception options are available for women?",
     "Options include combined pills, progestogen-only pills, patches, vaginal rings, "
     "injectables, implants, hormonal and copper IUDs, barrier methods, emergency "
     "contraception, and permanent sterilisation."),

    ("How can women reduce their risk of heart disease?",
     "Women can lower heart disease risk through regular exercise, a heart-healthy diet, "
     "not smoking, managing blood pressure and cholesterol, maintaining healthy weight, "
     "controlling blood sugar, reducing stress, and regular screenings."),

    # safety_support_advocacy
    ("What resources are available to women experiencing domestic violence?",
     "Resources include national crisis hotlines, women's shelters, legal aid, "
     "trauma-informed healthcare providers, counselling services, and online resources "
     "for safety planning, financial assistance, and relocation support."),
]


# ═══════════════════════════════════════════════════════════════════════════
#  METRICS
#
#  ResponseRelevancy(strictness=1) — prevents n > 1 LLM calls (Groq fix)
#  ragas.metrics path              — supports LangchainLLMWrapper
# ═══════════════════════════════════════════════════════════════════════════

METRICS = [
    Faithfulness(llm=evaluator_llm),
    ResponseRelevancy(
        llm        = evaluator_llm,
        embeddings = evaluator_embeddings,
        strictness = 1,     # prevents n > 1 Groq API calls
    ),
    LLMContextPrecisionWithoutReference(llm=evaluator_llm),
    LLMContextRecall(llm=evaluator_llm),
]

# NOTE: ResponseRelevancy stores results as "answer_relevancy" in the DataFrame
METRIC_LABELS: dict[str, str] = {
    "faithfulness"                            : "Faithfulness          ",
    "answer_relevancy"                        : "Answer Relevancy      ",
    "llm_context_precision_without_reference" : "Context Precision     ",
    "context_recall"                          : "Context Recall        ",
}


# ═══════════════════════════════════════════════════════════════════════════
#  BUILD EVALUATION DATASET
# ═══════════════════════════════════════════════════════════════════════════

def build_eval_dataset(
    data: list[tuple[str, str]],
    max_questions: int | None = None,
    sleep_between: float = 2.0,
) -> EvaluationDataset:

    if max_questions:
        data = data[:max_questions]

    samples: list[SingleTurnSample] = []
    total = len(data)

    print(f"\n📋 Running Aurora pipeline on {total} questions...\n" + "─" * 65)

    for idx, (question, ground_truth) in enumerate(data, 1):
        print(f"[{idx:02d}/{total}] {question[:62]}...")
        try:
            answer, contexts = generate_answer(question)
            samples.append(SingleTurnSample(
                user_input         = question,
                response           = answer,
                retrieved_contexts = contexts,
                reference          = ground_truth,
            ))
            print(f"         ✅  {len(contexts)} chunks | {len(answer)} char answer")
        except Exception as exc:
            print(f"         ❌  Skipped — {exc}")

        time.sleep(sleep_between)

    print("─" * 65)
    print(f"✅ Dataset ready: {len(samples)} / {total} samples\n")
    return EvaluationDataset(samples=samples)


# ═══════════════════════════════════════════════════════════════════════════
#  DISPLAY HELPERS
# ═══════════════════════════════════════════════════════════════════════════

def _safe_mean(series):
    clean = series.dropna()
    return float(clean.mean()) if len(clean) > 0 else None

def _rating(v):
    return "🟢 Excellent" if v >= 0.85 else "🟡 Good" if v >= 0.70 else "🟠 Moderate" if v >= 0.50 else "🔴 Poor"

def _bar(v, w=20):
    f = min(w, max(0, round(v * w)))
    return "█" * f + "░" * (w - f)


# ═══════════════════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════════════════

def main() -> None:
    parser = argparse.ArgumentParser(description="Aurora RAG evaluation with RAGAS")
    parser.add_argument("--output", "-o", default="eval_results.csv")
    parser.add_argument("--n", type=int, default=None, metavar="N")
    args = parser.parse_args()

    try:
        # Step 1 — build dataset
        eval_dataset = build_eval_dataset(TEST_DATASET, max_questions=args.n)

        # Step 2 — run RAGAS
        print("🧪 Running RAGAS evaluation (may take a few minutes)...\n")
        run_cfg = RunConfig(
            timeout     = 180,
            max_retries = 5,
            max_wait    = 60,
            max_workers = 1,    # sequential — avoids parallel Groq rate-limit errors
        )
        result = evaluate(dataset=eval_dataset, metrics=METRICS, run_config=run_cfg)

        # Step 3 — print summary
        df: pd.DataFrame = result.to_pandas()

        # Shows actual column names — helps debug any future label mismatches
        print(f"[debug] result columns: {list(df.columns)}\n")

        print("\n" + "═" * 65)
        print("  📊  AURORA  —  RAG EVALUATION RESULTS")
        print("═" * 65)

        score_cols: list[str] = []
        for key, label in METRIC_LABELS.items():
            if key not in df.columns:
                print(f"  {label}  [column '{key}' not found in results]")
                continue
            mean_val = _safe_mean(df[key])
            if mean_val is None:
                print(f"  {label}  [N/A — all jobs failed]")
                continue
            score_cols.append(key)
            print(f"  {label}  [{_bar(mean_val)}]  {mean_val:.4f}  {_rating(mean_val)}")

        if score_cols:
            df["_composite"] = df[score_cols].mean(axis=1)
            composite = float(df["_composite"].dropna().mean())
            print("─" * 65)
            print(f"  🏆 Composite Score             [{_bar(composite)}]  {composite:.4f}  ({composite*100:.1f}%)")

        print("═" * 65)

        # Step 4 — weakest questions
        if score_cols and len(df) > 1 and "_composite" in df.columns:
            worst = df.dropna(subset=["_composite"]).nsmallest(3, "_composite")
            if len(worst) > 0:
                print("\n⚠️  3 Weakest questions (targets for improvement):")
                for _, row in worst.iterrows():
                    print(f"   [{row['_composite']:.3f}]  {str(row.get('user_input',''))[:70]}")

        # Step 5 — save CSV
        out_path = Path(args.output)
        df.drop(columns=["_composite"], errors="ignore").to_csv(out_path, index=False)
        print(f"\n💾 Scores saved → {out_path}")
        print(f"   Columns: {[c for c in df.columns if not c.startswith('_')]}\n")

        # Step 6 — guidance
        print("📌 Interpretation:  🟢 ≥0.85 Excellent  🟡 0.70-0.85 Good  🟠 0.50-0.70 Moderate  🔴 <0.50 Poor\n")
        print("💡 Fixes:")
        print("   Low Faithfulness      → tighten RAG prompt, lower temperature")
        print("   Low Answer Relevancy  → improve router, refine system prompt")
        print("   Low Context Precision → reduce k or add re-ranking")
        print("   Low Context Recall    → increase k, improve chunking or add hybrid search\n")

    finally:
        try:
            _qdrant_client.close()
        except Exception:
            pass


if __name__ == "__main__":
    main()