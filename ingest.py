import os
import shutil
from typing import List, Dict

from langchain_community.document_loaders import (
    PyPDFDirectoryLoader,
    PyPDFLoader,
    WebBaseLoader
)
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_ollama import OllamaEmbeddings
from langchain_qdrant import QdrantVectorStore

# ---------------- CONFIG ---------------- #

DATASET_ROOT = "Aurora_Dataset"
QDRANT_PATH = "qdrant_db"
COLLECTION_NAME = "aurora_womens_health"

MASTER_PDF_NAME = "master_pdf.pdf"

CHUNK_SIZE = 500
CHUNK_OVERLAP = 50

# ---------------- URL DATA ---------------- #

URLS: List[Dict] = [
    {"url": "https://www.nhs.uk/conditions/periods/", "category": "hormonal_life_stages", "subcategory": "puberty_first_periods"},
    {"url": "https://www.mayoclinic.org/healthy-lifestyle/getting-pregnant/basics/conception/hlv-20049403", "category": "hormonal_life_stages", "subcategory": "fertility_pre_conception"},
    {"url": "https://www.who.int/news-room/fact-sheets/detail/maternal-mortality", "category": "hormonal_life_stages", "subcategory": "pregnancy_maternal_health"},
    {"url": "https://www.nhs.uk/conditions/baby/support-and-services/your-post-pregnancy-body/", "category": "hormonal_life_stages", "subcategory": "postpartum_4th_trimester"},
    {"url": "https://www.mayoclinic.org/diseases-conditions/menopause/symptoms-causes/syc-20353397", "category": "hormonal_life_stages", "subcategory": "perimenopause_menopause"},
    {"url": "https://www.who.int/news-room/fact-sheets/detail/polycystic-ovary-syndrome", "category": "daily_symptom_support", "subcategory": "pcos_awareness"},
    {"url": "https://www.nhs.uk/conditions/endometriosis/", "category": "daily_symptom_support", "subcategory": "endometriosis"},
    {"url": "https://www.mayoclinic.org/diseases-conditions/urinary-tract-infection/symptoms-causes/syc-20353447", "category": "daily_symptom_support", "subcategory": "uti_pelvic_health"},
    {"url": "https://www.nhs.uk/conditions/iron-deficiency-anaemia/", "category": "daily_symptom_support", "subcategory": "anemia_iron_deficiency"},
    {"url": "https://www.nin.res.in/dietaryguidelines/index.html", "category": "holistic_wellness_lifestyle", "subcategory": "nutrition_diet"},
    {"url": "https://www.healthline.com/health/womens-health/guide-to-cycle-syncing-how-it-works", "category": "holistic_wellness_lifestyle", "subcategory": "cycle_syncing_exercise"},
    {"url": "https://www.aad.org/public/diseases/acne/really-acne/adult-women", "category": "holistic_wellness_lifestyle", "subcategory": "skin_hair_care"},
    {"url": "https://www.nimh.nih.gov/health/publications/postpartum-depression-facts", "category": "mental_emotional_resilience", "subcategory": "postpartum_depression"},
    {"url": "https://www.mayoclinic.org/healthy-lifestyle/stress-management/basics/stress-relief/hlv-20049495", "category": "mental_emotional_resilience", "subcategory": "stress_management"},
    {"url": "https://www.cdc.gov/cancer/screening-tests/women.htm", "category": "preventive_care_screening", "subcategory": "cancer_screening"},
    {"url": "https://www.nhs.uk/conditions/contraception/", "category": "preventive_care_screening", "subcategory": "contraception_options"},
    {"url": "https://www.goredforwomen.org/en/about-heart-disease-in-women/signs-and-symptoms-in-women", "category": "preventive_care_screening", "subcategory": "heart_health"},
    {"url": "https://www.who.int/news-room/fact-sheets/detail/violence-against-women", "category": "safety_support_advocacy", "subcategory": "domestic_violence_resources"},
    {"url": "https://swhr.org/resource/women-wellness-health-advocacy-toolkit/", "category": "safety_support_advocacy", "subcategory": "medical_advocacy"},
]

# ---------------- INIT ---------------- #

print("🔌 Initializing embeddings...")
embeddings = OllamaEmbeddings(model="mxbai-embed-large")

text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=CHUNK_SIZE,
    chunk_overlap=CHUNK_OVERLAP
)

if os.path.exists(QDRANT_PATH):
    shutil.rmtree(QDRANT_PATH)

vectorstore = None  # lazy init

# ---------------- HELPERS ---------------- #

def ingest_documents(docs):
    global vectorstore

    if not docs:
        return

    chunks = text_splitter.split_documents(docs)
    if not chunks:
        return

    if vectorstore is None:
        vectorstore = QdrantVectorStore.from_documents(
            documents=chunks,
            embedding=embeddings,
            path=QDRANT_PATH,
            collection_name=COLLECTION_NAME
        )
    else:
        vectorstore.add_documents(chunks)

# ---------------- MASTER PDF INGESTION ---------------- #

print("\n📘 Ingesting master PDF...")

master_pdf_path = os.path.join(DATASET_ROOT, MASTER_PDF_NAME)

if os.path.isfile(master_pdf_path):
    try:
        loader = PyPDFLoader(master_pdf_path)
        docs = loader.load()

        if docs:
            for doc in docs:
                doc.metadata.update({
                    "category": "global_reference",
                    "subcategory": "master_document",
                    "source_type": "pdf"
                })

            ingest_documents(docs)
            print("✅ Master PDF embedded")
        else:
            print("⚠️ Master PDF found but empty")

    except Exception as e:
        print(f"❌ Failed to ingest master PDF: {e}")
else:
    print("ℹ️ No master PDF found at dataset root")

# ---------------- PDF FOLDER INGESTION ---------------- #

print("\n📂 Ingesting PDF folders...")

for category in os.listdir(DATASET_ROOT):
    category_path = os.path.join(DATASET_ROOT, category)
    if not os.path.isdir(category_path):
        continue

    for subfolder in os.listdir(category_path):
        subfolder_path = os.path.join(category_path, subfolder)
        if not os.path.isdir(subfolder_path):
            continue

        try:
            loader = PyPDFDirectoryLoader(subfolder_path)
            docs = loader.load()

            if not docs:
                print(f"⚠️ Empty folder skipped: {subfolder_path}")
                continue

            for doc in docs:
                doc.metadata.update({
                    "category": category,
                    "subcategory": subfolder,
                    "source_type": "pdf"
                })

            ingest_documents(docs)
            print(f"✅ Ingested PDFs: {category}/{subfolder}")

        except Exception as e:
            print(f"❌ Failed {subfolder_path}: {e}")

# ---------------- URL INGESTION ---------------- #

print("\n🌐 Ingesting URLs...")

for item in URLS:
    try:
        loader = WebBaseLoader(item["url"])
        docs = loader.load()

        if not docs:
            print(f"⚠️ Empty URL skipped: {item['url']}")
            continue

        for doc in docs:
            doc.metadata.update({
                "category": item["category"],
                "subcategory": item["subcategory"],
                "source_type": "url",
                "source": item["url"]
            })

        ingest_documents(docs)
        print(f"✅ Ingested URL: {item['url']}")

    except Exception as e:
        print(f"❌ URL failed {item['url']}: {e}")

# ---------------- DONE ---------------- #

print("\n✨ Ingestion complete!")
print(f"📦 Qdrant DB location: {QDRANT_PATH}")
print(f"📚 Collection: {COLLECTION_NAME}")
