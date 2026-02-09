from pathlib import Path
from qdrant_client import QdrantClient
from langchain_qdrant import QdrantVectorStore
from .embeddings import load_embeddings

QDRANT_PATH = Path("data/qdrant_db")
COLLECTION_NAME = "aurora_womens_health"

def load_vectorstore():
    client = QdrantClient(path=str(QDRANT_PATH))
    return QdrantVectorStore(
        client=client,
        collection_name=COLLECTION_NAME,
        embedding=load_embeddings()
    )
