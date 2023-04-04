import logging
import azure.functions as func
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential
from azure.ai.formrecognizer import DocumentAnalysisClient
from azure.core.credentials import AzureKeyCredential
from typing import List, Optional
import re
import openai
from openai.embeddings_utils import get_embedding
from elasticsearch import Elasticsearch, helpers


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


def generate_embedding(
    s: str, engine: Optional[str] = "microhack-curie-text-search-doc"
):
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
    embedding_dict = {"paragraph": cleaned_paragraph, "embedding": embedding}
    return embedding_dict


def doc_generator(docs, index, doc_type):
    """
    Generate Elasticsearch-compliant documents from a list of dictionaries
    """
    for doc in docs:
        yield {"_index": index, "_type": doc_type, "_source": doc}


def main(myblob: func.InputStream):
    logging.info(
        f"Python blob trigger function processed blob \n"
        f"Name: {myblob.name}\n"
        f"Blob Size: {myblob.length} bytes"
    )

    # Azure Credentials
    credential = DefaultAzureCredential()
    # Retrieve secrets from Key Vault
    key_vault_name = "microhack-key-vault"
    key_vault_uri = f"https://{key_vault_name}.vault.azure.net"
    client = SecretClient(vault_url=key_vault_uri, credential=credential)
    logging.info("Retreiving secrets from Azure Key Vault.")
    fm_api_key = client.get_secret("FORM-RECOGNIZER-KEY").value
    fm_endpoint = client.get_secret("FORM-RECOGNIZER-ENDPOINT").value

    # openai
    openai_api_key = client.get_secret("OPENAI-KEY").value
    openai_endpoint = client.get_secret("OPENAI-ENDPOINT").value
    openai.api_type = "azure"
    openai.api_key = openai_api_key
    openai.api_base = openai_endpoint
    openai.api_version = "2022-12-01"

    # elasticsearch
    es_scheme = "https"
    es_host = client.get_secret("ELASTICSEARCH-ENDPOINT").value
    es_port = 9200
    es_index = "qa-knowledge-base"
    es_doc_type = "paragraph"
    es_user = client.get_secret("ELASTICSEARCH-USER").value
    es_key = client.get_secret("ELASTICSEARCH-KEY").value
    es_auth = (es_user, es_key)
    es = Elasticsearch(
        [{"scheme": es_scheme, "host": es_host, "port": es_port}], basic_auth=es_auth
    )

    # Read document
    data = myblob.read()

    # Get List of paragraphs from document
    paragraphs = analyze_layout(data, fm_endpoint, fm_api_key)

    # Generate embeddings
    embeddings_dict = [generate_embedding(p) for p in paragraphs]
    logging.info(embeddings_dict)

    # index documents and embeddings to elasticsearch
    helpers.bulk(es, doc_generator(embeddings_dict, es_index, es_doc_type))
