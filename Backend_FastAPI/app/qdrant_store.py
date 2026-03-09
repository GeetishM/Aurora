from pathlib import Path
from qdrant_client import QdrantClient
from langchain_qdrant import QdrantVectorStore
from .embeddings import load_embeddings

QDRANT_PATH      = Path("qdrant_db")
COLLECTION_NAME  = "aurora_womens_health"


def load_vectorstore() -> QdrantVectorStore:
    client = QdrantClient(path=str(QDRANT_PATH))
    return QdrantVectorStore(
        client=client,
        collection_name=COLLECTION_NAME,
        embedding=load_embeddings(),
    )


def load_retriever():
    # MMR = Maximal Marginal Relevance: fetches 8 candidates, returns top 4
    # with diversity. lambda_mult controls relevance vs diversity balance:
    #   1.0 = pure relevance  |  0.0 = pure diversity  |  0.7 = good default
    #
    # NOTE: score_threshold is silently ignored with mmr — only valid with
    # search_type="similarity_score_threshold", so we don't pass it here.
    return load_vectorstore().as_retriever(
        search_type="mmr",
        search_kwargs={"k": 3, "fetch_k": 12, "lambda_mult": 0.7},
    )