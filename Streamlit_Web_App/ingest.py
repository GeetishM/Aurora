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

DATASET_ROOT = "Aurora_Datasets"
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

    # ── daily_symptom_support ─────────────────────────────────────────────────
    {"url": "https://www.nhs.uk/conditions/fibromyalgia/", "category": "daily_symptom_support", "subcategory": "chronic_conditions_awareness"},
    {"url": "https://www.cdc.gov/chronic-disease/fibromyalgia/index.html", "category": "daily_symptom_support", "subcategory": "chronic_conditions_awareness"},
    {"url": "https://womenshealth.gov/a-z-topics/fibromyalgia", "category": "daily_symptom_support", "subcategory": "chronic_conditions_awareness"},
    {"url": "https://www.nhs.uk/conditions/thyroid-cancer/", "category": "daily_symptom_support", "subcategory": "autoimmune_endocrine"},
    {"url": "https://www.nhs.uk/conditions/overactive-thyroid-hyperthyroidism/", "category": "daily_symptom_support", "subcategory": "autoimmune_endocrine"},
    {"url": "https://www.nhs.uk/conditions/underactive-thyroid-hypothyroidism/", "category": "daily_symptom_support", "subcategory": "autoimmune_endocrine"},
    {"url": "https://womenshealth.gov/a-z-topics/lupus", "category": "daily_symptom_support", "subcategory": "autoimmune_endocrine"},
    {"url": "https://www.nhs.uk/conditions/heavy-periods/", "category": "daily_symptom_support", "subcategory": "menstrual_health"},
    {"url": "https://www.nhs.uk/conditions/stopped-or-irregular-periods/", "category": "daily_symptom_support", "subcategory": "menstrual_health"},
    {"url": "https://www.nhs.uk/conditions/pelvic-inflammatory-disease-pid/", "category": "daily_symptom_support", "subcategory": "infection_pelvic_health"},
    {"url": "https://www.nhs.uk/conditions/bacterial-vaginosis/", "category": "daily_symptom_support", "subcategory": "infection_pelvic_health"},
    {"url": "https://www.nhs.uk/conditions/thrush-in-women-and-men/", "category": "daily_symptom_support", "subcategory": "infection_pelvic_health"},

    # ── hormonal_life_stages ──────────────────────────────────────────────────
    {"url": "https://www.nhs.uk/conditions/puberty/", "category": "hormonal_life_stages", "subcategory": "adolescence_puberty"},
    {"url": "https://www.mayoclinic.org/healthy-lifestyle/womens-health/in-depth/menstrual-cycle/art-20047186", "category": "hormonal_life_stages", "subcategory": "adolescence_puberty"},
    {"url": "https://www.nhs.uk/pregnancy/labour-and-birth/signs-of-labour/signs-that-labour-has-begun/", "category": "hormonal_life_stages", "subcategory": "pregnancy_maternal_health"},
    {"url": "https://www.who.int/news-room/fact-sheets/detail/preterm-birth", "category": "hormonal_life_stages", "subcategory": "pregnancy_maternal_health"},
    {"url": "https://www.nhs.uk/conditions/miscarriage/", "category": "hormonal_life_stages", "subcategory": "preconception_fertility"},
    {"url": "https://www.mayoclinic.org/diseases-conditions/infertility/symptoms-causes/syc-20354317", "category": "hormonal_life_stages", "subcategory": "preconception_fertility"},

    # ── holistic_wellness_lifestyle ───────────────────────────────────────────
    {"url": "https://www.nhs.uk/every-mind-matters/mental-wellbeing-tips/how-to-fall-asleep-faster-and-sleep-better/", "category": "holistic_wellness_lifestyle", "subcategory": "sleep_optimization"},
    {"url": "https://www.cdc.gov/sleep/about/index.html", "category": "holistic_wellness_lifestyle", "subcategory": "sleep_optimization"},
    {"url": "https://www.mayoclinic.org/healthy-lifestyle/fitness/basics/fitness-basics/hlv-20049447", "category": "holistic_wellness_lifestyle", "subcategory": "cycle_syncing_exercise"},
    {"url": "https://www.nhs.uk/live-well/eat-well/", "category": "holistic_wellness_lifestyle", "subcategory": "nutrition_diet"},

    # ── mental_emotional_resilience ───────────────────────────────────────────
    {"url": "https://www.nimh.nih.gov/health/publications/depression-in-women", "category": "mental_emotional_resilience", "subcategory": "cognitive_health"},
    {"url": "https://www.nimh.nih.gov/health/publications/anxiety-disorders", "category": "mental_emotional_resilience", "subcategory": "cognitive_health"},
    {"url": "https://www.nhs.uk/mental-health/conditions/depression-in-adults/overview/", "category": "mental_emotional_resilience", "subcategory": "emotional_support"},
    {"url": "https://www.nhs.uk/mental-health/conditions/eating-disorders/overview/", "category": "mental_emotional_resilience", "subcategory": "emotional_support"},
    {"url": "https://www.nimh.nih.gov/health/publications/post-traumatic-stress-disorder-ptsd", "category": "mental_emotional_resilience", "subcategory": "emotional_support"},
    {"url": "https://www.nhs.uk/mental-health/self-help/guides-tools-and-activities/breathing-exercises-for-stress/", "category": "mental_emotional_resilience", "subcategory": "somatic_wellness"},

    # ── preventive_care_screening ─────────────────────────────────────────────
    {"url": "https://www.cdc.gov/cancer/cervical/index.html", "category": "preventive_care_screening", "subcategory": "cancer_awareness"},
    {"url": "https://www.nhs.uk/conditions/cervical-cancer/", "category": "preventive_care_screening", "subcategory": "cancer_awareness"},
    {"url": "https://www.niams.nih.gov/health-topics/osteoporosis", "category": "preventive_care_screening", "subcategory": "heart_bone_health"},
    {"url": "https://www.nhs.uk/conditions/osteoporosis/", "category": "preventive_care_screening", "subcategory": "heart_bone_health"},
    {"url": "https://www.nhs.uk/conditions/sexual-health/", "category": "preventive_care_screening", "subcategory": "sexual_health"},
    {"url": "https://www.who.int/news-room/fact-sheets/detail/sexually-transmitted-infections-(stis)", "category": "preventive_care_screening", "subcategory": "sexual_health"},

    # ── safety_support_advocacy ───────────────────────────────────────────────
    {"url": "https://www.who.int/news-room/fact-sheets/detail/female-genital-mutilation", "category": "safety_support_advocacy", "subcategory": "domestic_safety_resources"},
    {"url": "https://www.nhs.uk/conditions/female-genital-mutilation-fgm/", "category": "safety_support_advocacy", "subcategory": "domestic_safety_resources"},

    # INDIAN GOVERNMENT SOURCES — replace/supplement NHS/Mayo

    # ── daily_symptom_support ─────────────────────────────────
    {"url": "https://www.nhp.gov.in/disease/gynaecology-and-obstetrics/polycystic-ovarian-syndrome-pcos", "category": "daily_symptom_support", "subcategory": "pcos_awareness"},
    {"url": "https://www.nhp.gov.in/disease/gynaecology-and-obstetrics/endometriosis", "category": "daily_symptom_support", "subcategory": "endometriosis"},
    {"url": "https://www.nhp.gov.in/disease/gynaecology-and-obstetrics/abnormal-uterine-bleeding", "category": "daily_symptom_support", "subcategory": "menstrual_health"},
    {"url": "https://www.nhp.gov.in/disease/blood-lymphatic/anaemia", "category": "daily_symptom_support", "subcategory": "anemia_iron_deficiency"},
    {"url": "https://www.nhp.gov.in/disease/gynaecology-and-obstetrics/anaemia-during-pregnancy-maternal-anemia", "category": "daily_symptom_support", "subcategory": "anemia_iron_deficiency"},
    {"url": "https://www.nhp.gov.in/disease/gynaecology-and-obstetrics/urinary-tract-infection", "category": "daily_symptom_support", "subcategory": "uti_pelvic_health"},
    {"url": "https://www.nhp.gov.in/disease/endocrine-system/thyroid-disorders", "category": "daily_symptom_support", "subcategory": "autoimmune_endocrine"},
    {"url": "https://www.nhp.gov.in/disease/musculo-skeltal-system/fibromyalgia", "category": "daily_symptom_support", "subcategory": "chronic_conditions_awareness"},

    # ── hormonal_life_stages ──────────────────────────────────
    {"url": "https://nhm.gov.in/index1.php?lang=1&level=2&sublinkid=818&lid=221", "category": "hormonal_life_stages", "subcategory": "adolescence_puberty"},
    {"url": "https://nhm.gov.in/index1.php?lang=1&level=2&lid=218&sublinkid=822", "category": "hormonal_life_stages", "subcategory": "pregnancy_maternal_health"},
    {"url": "https://www.nhp.gov.in/disease/gynaecology-and-obstetrics/menopause", "category": "hormonal_life_stages", "subcategory": "perimenopause_menopause"},
    {"url": "https://www.nhp.gov.in/disease/gynaecology-and-obstetrics/postpartum-depression", "category": "hormonal_life_stages", "subcategory": "postpartum_4th_trimester"},
    {"url": "https://www.nhp.gov.in/disease/gynaecology-and-obstetrics/infertility", "category": "hormonal_life_stages", "subcategory": "fertility_pre_conception"},
    {"url": "https://www.nhp.gov.in/pregnancy", "category": "hormonal_life_stages", "subcategory": "pregnancy_maternal_health"},

    # ── holistic_wellness_lifestyle ───────────────────────────
    {"url": "https://www.nhp.gov.in/healthylivingViewmore/diet-and-nutrition", "category": "holistic_wellness_lifestyle", "subcategory": "nutrition_diet"},
    {"url": "https://www.icmr.gov.in/cto_pdf/Dietary_Guidelines_2024.pdf", "category": "holistic_wellness_lifestyle", "subcategory": "nutrition_diet"},
    {"url": "https://www.nin.res.in/dietaryguidelines/index.html", "category": "holistic_wellness_lifestyle", "subcategory": "nutrition_diet"},
    {"url": "https://www.nhp.gov.in/healthlyliving/mental-health", "category": "holistic_wellness_lifestyle", "subcategory": "sleep_optimization"},
    {"url": "https://www.nhp.gov.in/healthylivingViewmore/yoga-benefits", "category": "holistic_wellness_lifestyle", "subcategory": "cycle_syncing_exercise"},

    # ── mental_emotional_resilience ───────────────────────────
    {"url": "https://www.nhp.gov.in/disease/mental-health/depression", "category": "mental_emotional_resilience", "subcategory": "emotional_support"},
    {"url": "https://www.nhp.gov.in/disease/mental-health/anxiety-disorders", "category": "mental_emotional_resilience", "subcategory": "cognitive_health"},
    {"url": "https://www.nhp.gov.in/disease/gynaecology-and-obstetrics/postpartum-depression", "category": "mental_emotional_resilience", "subcategory": "emotional_support"},
    {"url": "https://nimhans.ac.in/mental-health-education/", "category": "mental_emotional_resilience", "subcategory": "cognitive_health"},
    {"url": "https://www.nhp.gov.in/healthlyliving/stress-management", "category": "mental_emotional_resilience", "subcategory": "somatic_wellness"},

    # ── preventive_care_screening ─────────────────────────────
    {"url": "https://www.nhp.gov.in/disease/communicable-disease/human-papillomavirus-hpv-infection-and-cervical-cancer", "category": "preventive_care_screening", "subcategory": "cancer_screening"},
    {"url": "https://www.nhp.gov.in/disease/gynaecology-and-obstetrics/breast-cancer", "category": "preventive_care_screening", "subcategory": "cancer_screening"},
    {"url": "https://www.nhp.gov.in/disease/musculo-skeltal-system/osteoporosis", "category": "preventive_care_screening", "subcategory": "heart_bone_health"},
    {"url": "https://www.nhp.gov.in/disease/cardiovascular-heart-disease/coronary-artery-disease", "category": "preventive_care_screening", "subcategory": "heart_bone_health"},
    {"url": "https://www.nhp.gov.in/disease/gynaecology-and-obstetrics/contraception", "category": "preventive_care_screening", "subcategory": "contraception_options"},
    {"url": "https://nhm.gov.in/index1.php?lang=1&level=1&sublinkid=1041&lid=614", "category": "preventive_care_screening", "subcategory": "cancer_screening"},

    # ── safety_support_advocacy ───────────────────────────────
    {"url": "https://wcd.nic.in/schemes/one-stop-centre-scheme", "category": "safety_support_advocacy", "subcategory": "domestic_violence_resources"},
    {"url": "https://www.nhp.gov.in/disease/gynaecology-and-obstetrics/domestic-violence", "category": "safety_support_advocacy", "subcategory": "domestic_violence_resources"},
    {"url": "https://wcd.nic.in/schemes/swadhar-greh", "category": "safety_support_advocacy", "subcategory": "domestic_violence_resources"},
    {"url": "https://wcd.nic.in/womendevelopment/protection-women-domestic-violence-act-2005", "category": "safety_support_advocacy", "subcategory": "medical_advocacy"},
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
