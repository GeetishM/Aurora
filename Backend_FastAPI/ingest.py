import os
import shutil
import ssl
import requests
from typing import List, Dict

from langchain_community.document_loaders import (
    PyPDFDirectoryLoader,
    PyPDFLoader,
    WebBaseLoader,
)
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_ollama import OllamaEmbeddings
from langchain_qdrant import QdrantVectorStore
from qdrant_client import QdrantClient

# ---------------- CONFIG ---------------- #

DATASET_ROOT    = "Aurora_Datasets"
QDRANT_PATH     = "qdrant_db"
COLLECTION_NAME = "aurora_womens_health"
MASTER_PDF_NAME = "master_pdf.pdf"

CHUNK_SIZE    = 500
CHUNK_OVERLAP = 50

# ============================================================
#  URL LIST — CLEAN (all verified working)
#
#  REMOVED:
#    nhp.gov.in   → blocks automated scrapers (DNS fails)
#    wcd.nic.in   → blocks automated scrapers (DNS fails)
#    nimhans.ac.in → SSL certificate error
#
#  REPLACED with equivalent content from WHO / NHS / Mayo /
#  CDC / NIMH / Healthline / womenshealth.gov / icmr.gov.in
#  (all scraper-friendly and cover the same Indian-relevant topics)
# ============================================================

URLS: List[Dict] = [

    # ── hormonal_life_stages ──────────────────────────────────────────────
    {"url": "https://www.nhs.uk/conditions/periods/",
     "category": "hormonal_life_stages", "subcategory": "puberty_first_periods"},

    {"url": "https://www.nhs.uk/conditions/puberty/",
     "category": "hormonal_life_stages", "subcategory": "adolescence_puberty"},

    {"url": "https://www.mayoclinic.org/healthy-lifestyle/womens-health/in-depth/menstrual-cycle/art-20047186",
     "category": "hormonal_life_stages", "subcategory": "adolescence_puberty"},

    {"url": "https://www.mayoclinic.org/healthy-lifestyle/getting-pregnant/basics/conception/hlv-20049403",
     "category": "hormonal_life_stages", "subcategory": "fertility_pre_conception"},

    {"url": "https://www.mayoclinic.org/diseases-conditions/infertility/symptoms-causes/syc-20354317",
     "category": "hormonal_life_stages", "subcategory": "preconception_fertility"},

    {"url": "https://www.nhs.uk/conditions/miscarriage/",
     "category": "hormonal_life_stages", "subcategory": "preconception_fertility"},

    {"url": "https://www.who.int/news-room/fact-sheets/detail/maternal-mortality",
     "category": "hormonal_life_stages", "subcategory": "pregnancy_maternal_health"},

    {"url": "https://www.nhs.uk/pregnancy/labour-and-birth/signs-of-labour/signs-that-labour-has-begun/",
     "category": "hormonal_life_stages", "subcategory": "pregnancy_maternal_health"},

    {"url": "https://www.who.int/news-room/fact-sheets/detail/preterm-birth",
     "category": "hormonal_life_stages", "subcategory": "pregnancy_maternal_health"},

    # NHM India — adolescent & maternal health (confirmed working)
    {"url": "https://nhm.gov.in/index1.php?lang=1&level=2&sublinkid=818&lid=221",
     "category": "hormonal_life_stages", "subcategory": "adolescence_puberty"},

    {"url": "https://nhm.gov.in/index1.php?lang=1&level=2&lid=218&sublinkid=822",
     "category": "hormonal_life_stages", "subcategory": "pregnancy_maternal_health"},

    {"url": "https://www.nhs.uk/conditions/baby/support-and-services/your-post-pregnancy-body/",
     "category": "hormonal_life_stages", "subcategory": "postpartum_4th_trimester"},

    {"url": "https://www.mayoclinic.org/diseases-conditions/menopause/symptoms-causes/syc-20353397",
     "category": "hormonal_life_stages", "subcategory": "perimenopause_menopause"},

    {"url": "https://www.mayoclinic.org/diseases-conditions/perimenopause/symptoms-causes/syc-20354666",
     "category": "hormonal_life_stages", "subcategory": "perimenopause_menopause"},

    # ── daily_symptom_support ─────────────────────────────────────────────

    # PCOS — WHO + Mayo + womenshealth.gov (replaces nhp PCOS page)
    {"url": "https://www.who.int/news-room/fact-sheets/detail/polycystic-ovary-syndrome",
     "category": "daily_symptom_support", "subcategory": "pcos_awareness"},

    {"url": "https://www.mayoclinic.org/diseases-conditions/pcos/symptoms-causes/syc-20353439",
     "category": "daily_symptom_support", "subcategory": "pcos_awareness"},

    {"url": "https://womenshealth.gov/a-z-topics/polycystic-ovary-syndrome",
     "category": "daily_symptom_support", "subcategory": "pcos_awareness"},

    # Endometriosis
    {"url": "https://www.nhs.uk/conditions/endometriosis/",
     "category": "daily_symptom_support", "subcategory": "endometriosis"},

    {"url": "https://www.who.int/news-room/fact-sheets/detail/endometriosis",
     "category": "daily_symptom_support", "subcategory": "endometriosis"},

    # Menstrual health (replaces nhp abnormal uterine bleeding page)
    {"url": "https://www.nhs.uk/conditions/heavy-periods/",
     "category": "daily_symptom_support", "subcategory": "menstrual_health"},

    {"url": "https://www.nhs.uk/conditions/stopped-or-irregular-periods/",
     "category": "daily_symptom_support", "subcategory": "menstrual_health"},

    {"url": "https://womenshealth.gov/a-z-topics/menstruation-and-menstrual-problems",
     "category": "daily_symptom_support", "subcategory": "menstrual_health"},

    # Anaemia — WHO + NHS (replaces nhp anaemia pages; high India relevance)
    {"url": "https://www.nhs.uk/conditions/iron-deficiency-anaemia/",
     "category": "daily_symptom_support", "subcategory": "anemia_iron_deficiency"},

    {"url": "https://www.who.int/news-room/fact-sheets/detail/anaemia",
     "category": "daily_symptom_support", "subcategory": "anemia_iron_deficiency"},

    {"url": "https://womenshealth.gov/a-z-topics/anemia",
     "category": "daily_symptom_support", "subcategory": "anemia_iron_deficiency"},

    # UTI / pelvic health
    {"url": "https://www.mayoclinic.org/diseases-conditions/urinary-tract-infection/symptoms-causes/syc-20353447",
     "category": "daily_symptom_support", "subcategory": "uti_pelvic_health"},

    {"url": "https://www.nhs.uk/conditions/urinary-tract-infections-utis/",
     "category": "daily_symptom_support", "subcategory": "uti_pelvic_health"},

    {"url": "https://www.nhs.uk/conditions/pelvic-inflammatory-disease-pid/",
     "category": "daily_symptom_support", "subcategory": "infection_pelvic_health"},

    {"url": "https://www.nhs.uk/conditions/bacterial-vaginosis/",
     "category": "daily_symptom_support", "subcategory": "infection_pelvic_health"},

    {"url": "https://www.nhs.uk/conditions/thrush-in-women-and-men/",
     "category": "daily_symptom_support", "subcategory": "infection_pelvic_health"},

    # Thyroid (replaces nhp thyroid page)
    {"url": "https://www.nhs.uk/conditions/overactive-thyroid-hyperthyroidism/",
     "category": "daily_symptom_support", "subcategory": "autoimmune_endocrine"},

    {"url": "https://www.nhs.uk/conditions/underactive-thyroid-hypothyroidism/",
     "category": "daily_symptom_support", "subcategory": "autoimmune_endocrine"},

    {"url": "https://womenshealth.gov/a-z-topics/thyroid-disease",
     "category": "daily_symptom_support", "subcategory": "autoimmune_endocrine"},

    {"url": "https://womenshealth.gov/a-z-topics/lupus",
     "category": "daily_symptom_support", "subcategory": "autoimmune_endocrine"},

    {"url": "https://www.mayoclinic.org/diseases-conditions/type-2-diabetes/symptoms-causes/syc-20351193",
     "category": "daily_symptom_support", "subcategory": "autoimmune_endocrine"},

    # Chronic conditions (replaces nhp fibromyalgia page)
    {"url": "https://www.nhs.uk/conditions/fibromyalgia/",
     "category": "daily_symptom_support", "subcategory": "chronic_conditions_awareness"},

    {"url": "https://womenshealth.gov/a-z-topics/fibromyalgia",
     "category": "daily_symptom_support", "subcategory": "chronic_conditions_awareness"},

    {"url": "https://www.nhs.uk/conditions/chronic-fatigue-syndrome-cfs/",
     "category": "daily_symptom_support", "subcategory": "chronic_conditions_awareness"},

    # ── holistic_wellness_lifestyle ───────────────────────────────────────

    # Nutrition — ICMR + NIN confirmed working; replaces nhp nutrition page
    {"url": "https://www.icmr.gov.in/cto_pdf/Dietary_Guidelines_2024.pdf",
     "category": "holistic_wellness_lifestyle", "subcategory": "nutrition_diet"},

    {"url": "https://www.nin.res.in/dietaryguidelines/index.html",
     "category": "holistic_wellness_lifestyle", "subcategory": "nutrition_diet"},

    {"url": "https://www.nhs.uk/live-well/eat-well/",
     "category": "holistic_wellness_lifestyle", "subcategory": "nutrition_diet"},

    {"url": "https://www.mayoclinic.org/healthy-lifestyle/nutrition-and-healthy-eating/basics/nutrition-basics/hlv-20049477",
     "category": "holistic_wellness_lifestyle", "subcategory": "nutrition_diet"},

    # Cycle syncing / exercise
    {"url": "https://www.healthline.com/health/womens-health/guide-to-cycle-syncing-how-it-works",
     "category": "holistic_wellness_lifestyle", "subcategory": "cycle_syncing_exercise"},

    {"url": "https://www.mayoclinic.org/healthy-lifestyle/fitness/basics/fitness-basics/hlv-20049447",
     "category": "holistic_wellness_lifestyle", "subcategory": "cycle_syncing_exercise"},

    # Skin & hair
    {"url": "https://www.aad.org/public/diseases/acne/really-acne/adult-women",
     "category": "holistic_wellness_lifestyle", "subcategory": "skin_hair_care"},

    {"url": "https://womenshealth.gov/a-z-topics/acne",
     "category": "holistic_wellness_lifestyle", "subcategory": "skin_hair_care"},

    # Sleep (replaces nhp mental-health/sleep page)
    {"url": "https://www.nhs.uk/every-mind-matters/mental-wellbeing-tips/how-to-fall-asleep-faster-and-sleep-better/",
     "category": "holistic_wellness_lifestyle", "subcategory": "sleep_optimization"},

    {"url": "https://www.cdc.gov/sleep/about/index.html",
     "category": "holistic_wellness_lifestyle", "subcategory": "sleep_optimization"},

    {"url": "https://www.mayoclinic.org/healthy-lifestyle/adult-health/in-depth/sleep/art-20048379",
     "category": "holistic_wellness_lifestyle", "subcategory": "sleep_optimization"},

    # ── mental_emotional_resilience ───────────────────────────────────────

    # Postpartum depression
    {"url": "https://www.nimh.nih.gov/health/publications/postpartum-depression-facts",
     "category": "mental_emotional_resilience", "subcategory": "postpartum_depression"},

    {"url": "https://www.mayoclinic.org/diseases-conditions/postpartum-depression/symptoms-causes/syc-20376617",
     "category": "mental_emotional_resilience", "subcategory": "postpartum_depression"},

    # Depression & anxiety (replaces nhp depression/anxiety pages + nimhans)
    {"url": "https://www.nimh.nih.gov/health/publications/depression-in-women",
     "category": "mental_emotional_resilience", "subcategory": "cognitive_health"},

    {"url": "https://www.nimh.nih.gov/health/publications/anxiety-disorders",
     "category": "mental_emotional_resilience", "subcategory": "cognitive_health"},

    {"url": "https://www.nhs.uk/mental-health/conditions/depression-in-adults/overview/",
     "category": "mental_emotional_resilience", "subcategory": "emotional_support"},

    {"url": "https://www.nhs.uk/mental-health/conditions/eating-disorders/overview/",
     "category": "mental_emotional_resilience", "subcategory": "emotional_support"},

    {"url": "https://www.nimh.nih.gov/health/publications/post-traumatic-stress-disorder-ptsd",
     "category": "mental_emotional_resilience", "subcategory": "emotional_support"},

    {"url": "https://www.who.int/news-room/fact-sheets/detail/mental-disorders",
     "category": "mental_emotional_resilience", "subcategory": "cognitive_health"},

    # Stress & somatic wellness (replaces nhp stress page)
    {"url": "https://www.mayoclinic.org/healthy-lifestyle/stress-management/basics/stress-relief/hlv-20049495",
     "category": "mental_emotional_resilience", "subcategory": "stress_management"},

    {"url": "https://www.nhs.uk/mental-health/self-help/guides-tools-and-activities/breathing-exercises-for-stress/",
     "category": "mental_emotional_resilience", "subcategory": "somatic_wellness"},

    {"url": "https://www.healthline.com/health/mind-body/somatic-exercises",
     "category": "mental_emotional_resilience", "subcategory": "somatic_wellness"},

    # ── preventive_care_screening ─────────────────────────────────────────

    # Cancer (replaces nhp cervical/breast cancer pages)
    {"url": "https://www.cdc.gov/cancer/screening-tests/women.htm",
     "category": "preventive_care_screening", "subcategory": "cancer_screening"},

    {"url": "https://www.cdc.gov/cancer/cervical/index.html",
     "category": "preventive_care_screening", "subcategory": "cancer_awareness"},

    {"url": "https://www.nhs.uk/conditions/cervical-cancer/",
     "category": "preventive_care_screening", "subcategory": "cancer_awareness"},

    {"url": "https://www.who.int/news-room/fact-sheets/detail/cervical-cancer",
     "category": "preventive_care_screening", "subcategory": "cancer_awareness"},

    {"url": "https://www.mayoclinic.org/diseases-conditions/breast-cancer/symptoms-causes/syc-20352470",
     "category": "preventive_care_screening", "subcategory": "cancer_awareness"},

    # NHM India cancer screening (confirmed working)
    {"url": "https://nhm.gov.in/index1.php?lang=1&level=1&sublinkid=1041&lid=614",
     "category": "preventive_care_screening", "subcategory": "cancer_screening"},

    # Heart & bone health (replaces nhp osteoporosis/heart pages)
    {"url": "https://www.goredforwomen.org/en/about-heart-disease-in-women/signs-and-symptoms-in-women",
     "category": "preventive_care_screening", "subcategory": "heart_health"},

    {"url": "https://www.mayoclinic.org/diseases-conditions/heart-disease/in-depth/heart-disease/art-20049003",
     "category": "preventive_care_screening", "subcategory": "heart_bone_health"},

    {"url": "https://www.niams.nih.gov/health-topics/osteoporosis",
     "category": "preventive_care_screening", "subcategory": "heart_bone_health"},

    {"url": "https://www.nhs.uk/conditions/osteoporosis/",
     "category": "preventive_care_screening", "subcategory": "heart_bone_health"},

    # Contraception (replaces nhp contraception page)
    {"url": "https://www.nhs.uk/conditions/contraception/",
     "category": "preventive_care_screening", "subcategory": "contraception_options"},

    {"url": "https://www.mayoclinic.org/healthy-lifestyle/birth-control/basics/birth-control-basics/hlv-20049454",
     "category": "preventive_care_screening", "subcategory": "contraception_options"},

    # Sexual health
    {"url": "https://www.nhs.uk/conditions/sexual-health/",
     "category": "preventive_care_screening", "subcategory": "sexual_health"},

    {"url": "https://www.who.int/news-room/fact-sheets/detail/sexually-transmitted-infections-(stis)",
     "category": "preventive_care_screening", "subcategory": "sexual_health"},

    # ── safety_support_advocacy ───────────────────────────────────────────

    # Domestic violence — WHO + UN Women + womenshealth.gov
    # (replaces wcd.nic.in + nhp domestic violence pages — all DNS blocked)
    {"url": "https://www.who.int/news-room/fact-sheets/detail/violence-against-women",
     "category": "safety_support_advocacy", "subcategory": "domestic_violence_resources"},

    {"url": "https://www.who.int/news-room/fact-sheets/detail/female-genital-mutilation",
     "category": "safety_support_advocacy", "subcategory": "domestic_violence_resources"},

    {"url": "https://www.nhs.uk/conditions/female-genital-mutilation-fgm/",
     "category": "safety_support_advocacy", "subcategory": "domestic_violence_resources"},

    {"url": "https://womenshealth.gov/relationships-and-safety/domestic-violence",
     "category": "safety_support_advocacy", "subcategory": "domestic_violence_resources"},

    {"url": "https://www.mayoclinic.org/healthy-lifestyle/adult-health/in-depth/domestic-violence/art-20048397",
     "category": "safety_support_advocacy", "subcategory": "domestic_violence_resources"},

    # Medical advocacy
    {"url": "https://swhr.org/resource/women-wellness-health-advocacy-toolkit/",
     "category": "safety_support_advocacy", "subcategory": "medical_advocacy"},

    {"url": "https://womenshealth.gov/a-z-topics/womens-health-and-the-law",
     "category": "safety_support_advocacy", "subcategory": "medical_advocacy"},
]

# ---------------- INIT ---------------- #

print("🔌 Initializing embeddings...")
embeddings = OllamaEmbeddings(model="mxbai-embed-large")

text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=CHUNK_SIZE,
    chunk_overlap=CHUNK_OVERLAP,
)

if os.path.exists(QDRANT_PATH):
    shutil.rmtree(QDRANT_PATH)

vectorstore   = None   # lazy init
qdrant_client = None   # kept for explicit close at end

# ---------------- HELPERS ---------------- #

def ingest_documents(docs):
    global vectorstore, qdrant_client

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
            collection_name=COLLECTION_NAME,
        )
        # Keep a reference so we can close cleanly at the end
        qdrant_client = vectorstore.client
    else:
        vectorstore.add_documents(chunks)

# ---------------- MASTER PDF INGESTION ---------------- #

print("\n📘 Ingesting master PDF...")

master_pdf_path = os.path.join(DATASET_ROOT, MASTER_PDF_NAME)

if os.path.isfile(master_pdf_path):
    try:
        loader = PyPDFLoader(master_pdf_path)
        docs   = loader.load()
        if docs:
            for doc in docs:
                doc.metadata.update({
                    "category": "global_reference",
                    "subcategory": "master_document",
                    "source_type": "pdf",
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
            docs   = loader.load()

            if not docs:
                print(f"⚠️ Empty folder skipped: {subfolder_path}")
                continue

            for doc in docs:
                doc.metadata.update({
                    "category": category,
                    "subcategory": subfolder,
                    "source_type": "pdf",
                })

            ingest_documents(docs)
            print(f"✅ Ingested PDFs: {category}/{subfolder}")

        except Exception as e:
            print(f"❌ Failed {subfolder_path}: {e}")

# ---------------- URL INGESTION ---------------- #

print("\n🌐 Ingesting URLs...")

failed_urls  = []
success_count = 0

for item in URLS:
    try:
        loader = WebBaseLoader(item["url"])
        docs   = loader.load()

        if not docs:
            print(f"⚠️ Empty URL skipped: {item['url']}")
            continue

        for doc in docs:
            doc.metadata.update({
                "category":    item["category"],
                "subcategory": item["subcategory"],
                "source_type": "url",
                "source":      item["url"],
            })

        ingest_documents(docs)
        print(f"✅ Ingested URL: {item['url']}")
        success_count += 1

    except Exception as e:
        short_err = str(e).split("\n")[0][:120]
        print(f"❌ URL failed {item['url']}: {short_err}")
        failed_urls.append(item["url"])

# ---------------- DONE ---------------- #

print("\n" + "=" * 60)
print("✨ Ingestion complete!")
print(f"📦 Qdrant DB  : {QDRANT_PATH}")
print(f"📚 Collection : {COLLECTION_NAME}")
print(f"✅ URLs loaded : {success_count} / {len(URLS)}")

if failed_urls:
    print(f"\n⚠️  {len(failed_urls)} URL(s) failed (add their content as PDFs instead):")
    for u in failed_urls:
        print(f"   • {u}")

# Clean Qdrant shutdown — prevents the ImportError on exit
try:
    if qdrant_client is not None:
        qdrant_client.close()
except Exception:
    pass