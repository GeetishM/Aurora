from pathlib import Path
from qdrant_client import QdrantClient
from langchain_qdrant import QdrantVectorStore
from .embeddings import load_embeddings

QDRANT_PATH      = Path("data/qdrant_db")
COLLECTION_NAME  = "aurora_womens_health"


def load_vectorstore() -> QdrantVectorStore:
    client = QdrantClient(path=str(QDRANT_PATH))
    return QdrantVectorStore(
        client=client,
        collection_name=COLLECTION_NAME,
        embedding=load_embeddings(),
    )


def load_retriever():
    """
    MMR retriever — same as Streamlit app.
    Fetches 8 candidates, returns top 4 with diversity (MMR).
    """
    return load_vectorstore().as_retriever(
        search_type="mmr",
        search_kwargs={"k": 4, "fetch_k": 8, "score_threshold": 0.30},
    )