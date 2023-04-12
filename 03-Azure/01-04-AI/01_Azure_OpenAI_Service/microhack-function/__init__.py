import logging
import urllib.request
import azure.functions as func
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential
from azure.ai.formrecognizer import DocumentAnalysisClient
from azure.core.credentials import AzureKeyCredential
from typing import List, Optional
import re
import openai
from openai.embeddings_utils import get_embedding
import chromadb
from chromadb.api.types import Documents, EmbeddingFunction, Embeddings
from chromadb.config import Settings


def chunk_paragraphs(paragraphs: List[str], max_words: int = 100) -> List[str]:
    """
    Chunk a list of paragraphs into chunks
    of approximately equal word count.
    """
    # Create a list of dictionaries with the paragraph as the
    # key and the word count as the value
    paragraphs = [{p: len(p.split())} for p in paragraphs]
    # Create a list of lists of paragraphs
    chunks = []
    # Iterate over the list of paragraphs
    for i, p in enumerate(paragraphs):
        # If the current chunk is empty, add the first paragraph to it
        if len(chunks) == 0:
            chunks.append([p])
        # If the current chunk is not empty, check if adding the
        # next paragraph will exceed the max word count
        else:
            # If adding the next paragraph will exceed the max word count,
            # start a new chunk
            if (
                sum([list(c.values())[0] for c in chunks[-1]]) + list(p.values())[0]
                > max_words
            ):
                chunks.append([p])
            # If adding the next paragraph will not exceed the max word
            # count, add it to the current chunk
            else:
                chunks[-1].append(p)
    # Create a list of strings from the list of lists of paragraphs
    chunks = [" ".join([list(c.keys())[0] for c in chunk]) for chunk in chunks]
    return chunks


def analyze_layout(data: bytes, endpoint: str, key: str) -> List[str]:
    """
    Analyze a document with the layout model.

    Args:
        data (bytes): Document data.
        endpoint (str): Endpoint URL.
        key (str): API key.

    Returns:
        List[str]: List of paragraphs.
    """
    # Create a client for the form recognizer service
    document_analysis_client = DocumentAnalysisClient(
        endpoint=endpoint, credential=AzureKeyCredential(key)
    )
    # Analyze the document with the layout model
    poller = document_analysis_client.begin_analyze_document("prebuilt-layout", data)
    # Get the results and extract the paragraphs
    # (title, section headings, and body)
    result = poller.result()
    paragraphs = [
        p.content
        for p in result.paragraphs
        if p.role in ["Title", "sectionHeading", None]
    ]
    # Chunk the paragraphs (max word count = 100)
    paragraphs = chunk_paragraphs(paragraphs)

    return paragraphs


def normalize_text(s: str) -> str:
    """
    Clean up a string by removing redundant
    whitespaces and cleaning up the punctuation.

    Args:
        s (str): The string to be cleaned.

    Returns:
        s (str): The cleaned string.
    """
    s = re.sub(r"\s+", " ", s).strip()
    s = re.sub(r". ,", "", s)
    s = s.replace("..", ".")
    s = s.replace(". .", ".")
    s = s.replace("\n", "")
    s = s.strip()

    return s


def generate_embedding(s: str, engine: Optional[str] = "microhack-ada-text-embedding"):
    """
    Clean the extracted paragraph before generating its' embedding.

    Args:
        s (str): The extracted paragraph.
        engine (str): The name of the embedding model.

    Returns:
        embedding_dict (dict): The cleaned paragraph and embedding
        as key value pairs.
    """
    cleaned_paragraph = normalize_text(s)
    embedding = get_embedding(cleaned_paragraph, engine)
    return embedding


class AzureOpenAIEmbeddings(EmbeddingFunction):
    def __init__(
        self,
        openai_api_key: str,
        openai_endpoint: str,
        model_name: Optional[str] = "microhack-curie-text-search-doc",
    ):
        self.model_name = model_name
        openai.api_type = "azure"
        openai.api_key = openai_api_key
        openai.api_base = openai_endpoint
        openai.api_version = "2022-12-01"

    def __call__(self, texts: Documents) -> Embeddings:
        return [generate_embedding(p, self.model_name) for p in texts]


def gen_ids(client: chromadb.Client, collection_name: str, documents: List) -> List:
    """Generate a list of ids for the documents to be inserted into the collection.

    Args:
        client (chromadb.Client): The client to use to connect to the database.
        collection_name (str): The name of the collection to insert the documents into.
        documents (List): The documents to be inserted into the collection.

    Returns:
        List: A list of ids for the documents to be inserted into the collection.
    """
    if collection_name not in [
        collection.name for collection in client.list_collections()
    ]:
        return ["id{}".format(count) for count in range(len(documents))]
    else:
        collection = client.get_collection(collection_name)
        return [
            "id{}".format(count)
            for count in range(collection.count(), collection.count() + len(documents))
        ]


def main(myblob: func.InputStream):
    logging.info(
        f"Python blob trigger function processed blob \n"
        f"Name: {myblob.name}\n"
        f"Blob Size: {myblob.length} bytes"
    )

    credential = DefaultAzureCredential()
    # Retrieve secrets from Key Vault
    key_vault_name = "microhack-key-vault"
    key_vault_uri = f"https://{key_vault_name}.vault.azure.net"
    client = SecretClient(vault_url=key_vault_uri, credential=credential)
    logging.info("Retreiving secrets from Azure Key Vault.")
    fm_api_key = client.get_secret("FORM-RECOGNIZER-KEY").value
    fm_endpoint = client.get_secret("FORM-RECOGNIZER-ENDPOINT").value

    # OpenAI
    openai_api_key = client.get_secret("OPENAI-KEY").value
    openai_endpoint = client.get_secret("OPENAI-ENDPOINT").value

    # Chroma
    chroma_address = client.get_secret("CHROMA-DB-ADDRESS").value

    # Chroma Client
    chroma_client = chromadb.Client(
        Settings(
            chroma_api_impl="rest",
            chroma_server_host=chroma_address,
            chroma_server_http_port="8000",
        )
    )
    # Ping Chroma
    chroma_client.heartbeat()
    logging.info(
        "Successfully connected to Chroma DB. Collections found: %s",
        chroma_client.list_collections(),
    )

    # Get a Chroma collection or create it if it doesn't exist already
    logging.info("Get or create the microhack colletion")
    collection = chroma_client.get_or_create_collection(
        "microhack-collection",
        embedding_function=AzureOpenAIEmbeddings(openai_api_key, openai_endpoint),
    )
    logging.info("Successfully retrieved microhack collection from Chroma DB.")

    # Read document
    logging.info("Read in new document")
    data = myblob.read()

    # Get List of paragraphs from document
    logging.info("Retrieve paragraphs from new document")
    paragraphs = analyze_layout(data, fm_endpoint, fm_api_key)

    # Generate embeddings and save to Chroma
    logging.info(
        """Add paragraphs to chroma collection.
                 Number of new paragraphs: %s""",
        len(paragraphs),
    )
    collection.add(
        documents=paragraphs, ids=gen_ids(client, "microhack-collection", paragraphs)
    )
    logging.info("Total number of documents in collection: %s", collection.count())
