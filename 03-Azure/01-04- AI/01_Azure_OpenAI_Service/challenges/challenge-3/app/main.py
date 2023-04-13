import streamlit as st
from azure.storage.blob import BlobServiceClient
from azure.core.exceptions import ResourceExistsError
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential
import chromadb
from chromadb.config import Settings
import openai
from openai.embeddings_utils import get_embedding
from app_utils import create_prompt, list_sources

# Connect to key vault
credential = DefaultAzureCredential()
key_vault_name = "microhack-key-vault"
key_vault_uri = f"https://{key_vault_name}.vault.azure.net"
client = SecretClient(vault_url=key_vault_uri, credential=credential)

# Blob storage
account_name = "microhack"
account_key = client.get_secret("BLOB-KEY").value
container_name = "documents"

blob_service_client = BlobServiceClient(
    account_url=f"https://{account_name}.blob.core.windows.net", credential=account_key
)
container_client = blob_service_client.get_container_client(container_name)

# OpenAI
openai_api_key = client.get_secret("OPENAI-KEY").value
openai_endpoint = client.get_secret("OPENAI-ENDPOINT").value

openai.api_type = "azure"
openai.api_key = openai_api_key
openai.api_base = openai_endpoint
openai.api_version = "2022-12-01"

# Chroma
chroma_address = client.get_secret("CHROMA-DB-ADDRESS").value

chroma_client = chromadb.Client(
    Settings(
        chroma_api_impl="rest",
        chroma_server_host=chroma_address,
        chroma_server_http_port="8000",
    )
)

# Get collection
collection = chroma_client.get_collection("microhack-collection")

# App title
st.title("Microhack: Semantic Q&A-Bot")

# File upload in sidebar (only allows PDFs)
doc = st.sidebar.file_uploader(
    ":page_facing_up: Upload your own documents to the knowledge base here",
    type=["pdf"],
)

# Upload doc to blob storage and display status banner
if doc is not None:
    blob_client = container_client.get_blob_client(doc.name)

    try:
        blob_client.upload_blob(doc)
        st.sidebar.success("Document uploaded successfully!", icon="🚀")
    except ResourceExistsError:
        st.sidebar.error("Document was already uploaded!", icon="🛑")

# Query free-text window
st.markdown("### :question: Query the bot here:")
query = st.text_input("query", value="Who are statworx?", label_visibility="collapsed")

# Paragraph slider
n_paragraphs = st.slider(
    "Number of paragraphs to retrieve and source answer from:",
    min_value=1,
    max_value=5,
    value=3,
)

# Embed query
query_embedding = get_embedding(query, engine="microhack-ada-text-embedding")

# Query chroma collection
response = collection.query(
    query_embeddings=[query_embedding], n_results=n_paragraphs, include=["documents"]
)

# Generate answer with completion endpoint
completions = openai.Completion.create(
    engine="microhack-davinci-003-text-completion",  # the deployed model
    temperature=0.3,  # level of creativity in the response
    prompt=create_prompt(  # the retrieved paragraphs + query + fixed instructions
        response=response,  # the retrieved paragraphs
        query=query,  # the query
    ),
    max_tokens=n_paragraphs
    * 125,  # maximum tokens in both the prompt and completion, scales with n_paragraphs
    n=1,  # number of generated answers
)

# Display answer
st.markdown("### :robot_face: The Q&A-bot answers:")
st.write(completions["choices"][0]["text"])

# Display paragraphs
st.markdown(f"### :bulb: This answer was sourced from {n_paragraphs} paragraphs:")
st.write(list_sources(response))
