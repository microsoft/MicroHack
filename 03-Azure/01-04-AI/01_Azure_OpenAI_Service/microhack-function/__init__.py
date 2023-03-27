import logging
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential
from azure.ai.formrecognizer import DocumentAnalysisClient
from azure.core.credentials import AzureKeyCredential
import azure.functions as func
from typing import List


def chunk_paragraphs(paragraphs: List[str], max_words: int = 100) -> List[str]:
    """Chunk a list of paragraphs into chunks
    of approximately equal word count."""
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
            if sum(
                [list(c.values())[0] for c in chunks[-1]]
            ) + list(p.values())[0] > max_words:
                chunks.append([p])
            # If adding the next paragraph will not exceed the max word count,
            # add it to the current chunk
            else:
                chunks[-1].append(p)
    # Create a list of strings from the list of lists of paragraphs
    chunks = [" ".join([list(c.keys())[0] for c in chunk]) for chunk in chunks]
    return chunks


def analyze_layout(data, endpoint, key):
    document_analysis_client = DocumentAnalysisClient(
        endpoint=endpoint, credential=AzureKeyCredential(key)
    )

    poller = document_analysis_client.begin_analyze_document(
            "prebuilt-layout", data)
    result = poller.result()
    paragraphs = [
        p.content for p in result.paragraphs
        if p.role in ["Title", "sectionHeading", None]
        ]
    logging.info("RAW PARAGRAPHS:\n{}".format(paragraphs))
    paragraphs = chunk_paragraphs(paragraphs)
    logging.info("CLEANED PARAGRAPHS:\n{}".format(paragraphs))


def main(myblob: func.InputStream):
    logging.info(f"Python blob trigger function processed blob \n"
                 f"Name: {myblob.name}\n"
                 f"Blob Size: {myblob.length} bytes")

    # Azure Credentials
    credential = DefaultAzureCredential()
    # This is the call to the Form Recognizer endpoint
    key_vault_name = "microhack-key-vault"
    key_vault_uri = f"https://{key_vault_name}.vault.azure.net"
    client = SecretClient(vault_url=key_vault_uri, credential=credential)
    logging.info("Retreiving secrets from Azure Key Vault.")
    apim_key = client.get_secret("FORM-RECOGNIZER-KEY").value
    endpoint = client.get_secret("FORM-RECOGNIZER-ENDPOINT").value
    logging.info("ENDPOINT: {}".format(endpoint))
    data = myblob.read()
    analyze_layout(data, endpoint, apim_key)
