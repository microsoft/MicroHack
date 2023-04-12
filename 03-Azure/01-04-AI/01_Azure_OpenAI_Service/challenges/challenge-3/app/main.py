import streamlit as st
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential
import openai as ai
from openai.embeddings_utils import get_embedding
import chromadb
from chromadb.config import Settings
from app_utils import create_prompt, list_sources

# connect to key vault
credential = DefaultAzureCredential()
key_vault_name = "microhack-key-vault"
key_vault_uri = f"https://{key_vault_name}.vault.azure.net"
client = SecretClient(vault_url=key_vault_uri, credential=credential)

# openai
openai_api_key = client.get_secret("OPENAI-KEY").value
openai_endpoint = client.get_secret("OPENAI-ENDPOINT").value

ai.api_type = "azure"
ai.api_key = openai_api_key
ai.api_base = openai_endpoint
ai.api_version = "2022-12-01"

# chroma
chroma_address = client.get_secret("CHROMA-DB-ADDRESS").value

chroma_client = chromadb.Client(
    Settings(
        chroma_api_impl="rest",
        chroma_server_host=chroma_address,
        chroma_server_http_port="8000",
    )
)

# get collection
collection = chroma_client.get_collection("microhack-collection")

# app title
st.title("Microhack: Semantic Q&A-Bot")

# file upload in sidebar
doc = st.sidebar.file_uploader(
    ":page_facing_up: Upload your own documents to the knowledge base here"
)

# query free-text window
st.markdown("### :question: Query the bot here:")
query = st.text_input("query", value="Who are statworx?", label_visibility="collapsed")
n_paragraphs = st.slider(
    "Number of paragraphs to retrieve and source answer from:",
    min_value=1,
    max_value=5,
    value=3,
)

# embed query
query_embedding = get_embedding(query, engine="microhack-ada-text-embedding")

# query chroma collection
response = collection.query(
    query_embeddings=[query_embedding], n_results=n_paragraphs, include=["documents"]
)

# generate answer with completion endpoint
completions = ai.Completion.create(
    engine="microhack-davinci-003-text-completion",  # the deployed model
    temperature=0.3,  # level of creativity in the response
    prompt=create_prompt(
        response=response, query=query  # the retrieved paragraphs
    ),  # the query
    max_tokens=300,  # maximum tokens in both the prompt and completion
    n=1,  # number of answers to generate
)

# diplay answer
st.markdown("### :robot_face: The Q&A-bot answers:")
st.write(completions["choices"][0]["text"])

# display sources
st.markdown(f"### :bulb: This answer was sourced from {n_paragraphs} paragraphs:")
st.write(list_sources(response))
