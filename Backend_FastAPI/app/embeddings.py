from langchain_ollama import OllamaEmbeddings

def load_embeddings():
    return OllamaEmbeddings(model="mxbai-embed-large")
