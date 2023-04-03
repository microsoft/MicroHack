import openai
import re
import requests
from typing import Optional
import sys
from num2words import num2words
import os
import pandas as pd
import numpy as np
from openai.embeddings_utils import get_embedding

from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential
import logging
logging.basicConfig(level=logging.INFO)

def normalize_text(s: str) -> str:
    s = re.sub(r'\s+', " ", s).strip()
    s = re.sub(r". ,", "", s)
    # remove all instances of multiple spaces
    s = s.replace("..", ".")
    s = s.replace(". .", ".")
    s = s.replace("\n", "")
    s = s.strip()

    return s

def generate_embedding(s: str, engine: Optional[str] = "microhack-curie-text-search-doc"):
    cleaned_paragraph = normalize_text(s)
    embedding = get_embedding(cleaned_paragraph, engine)

    return {"paragraph": cleaned_paragraph, "embedding": embedding}


# Azure Credentials
credential = DefaultAzureCredential()
# This is the call to the Form Recognizer endpoint
key_vault_name = "microhack-key-vault"
key_vault_uri = f"https://{key_vault_name}.vault.azure.net"
client = SecretClient(vault_url=key_vault_uri, credential=credential)
logging.info("Retreiving secrets from Azure Key Vault.")
fm_api_key = client.get_secret("FORM-RECOGNIZER-KEY").value
fm_endpoint = client.get_secret("FORM-RECOGNIZER-ENDPOINT").value
openai_api_key = client.get_secret("OPENAI-KEY").value
openai_endpoint = client.get_secret("OPENAI-ENDPOINT").value
openai.api_type = "azure"
openai.api_key = openai_api_key
openai.api_base = openai_endpoint
openai.api_version = "2022-12-01"
url = openai.api_base + "/openai/deployments?api-version=2022-12-01"
r = requests.get(url, headers={"api-key": openai_api_key})
logging.info(r.text)

test_strings = ["""In our example, the user provides the query "can I get information on cable company tax revenue". The query is passed through a function that embeds the query with the corresponding query model and finds the embedding closest to it from the previously embedded documents in the previous step.""",
                """Finally, we'll show the top result from document search based on user query against the entire knowledge base. This returns the top result of the "Taxpayer's Right to View Act of 1993". This document has a cosine similarity score of 0.36 between the query and the document:"""]

embeddings_dict = [generate_embedding(p) for p in test_strings]
logging.info(embeddings_dict)
