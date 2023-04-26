# Walkthrough Challenge 3 -  Create a Graphical User Interface with Streamlit

Duration: **1 hour**

**[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-4/solution.md)

- [Walkthrough Challenge 3 -  Create a Graphical User Interface with Streamlit](#walkthrough-challenge-3----create-a-graphical-user-interface-with-streamlit)
  - [Prerequisites](#prerequisites)
  - [Task 1: Setup Streamlit App](#task-1-setup-streamlit-app)
  - [Task 2: Create Streamlit Widgets](#task-2-create-streamlit-widgets)
  - [Task 3: Connect the Streamlit App to the Blob Storage](#task-3-connect-the-streamlit-app-to-the-blob-storage)
  - [Task 4: Connect the Streamlit App to the Chroma DB and Retrieve Relevant Paragraphs](#task-4-connect-the-streamlit-app-to-the-chroma-db-and-retrieve-relevant-paragraphs)
  - [Task 5: Generate Answers via the Completions Endpoint](#task-5-generate-answers-via-the-completions-endpoint)

## Prerequisites

In order to complete Challenge 3, make sure that you have successfully completed Challenge 1 and 2, meaning that you should have a running Chroma Database as well as a functioning Azure Function.

## Task 1: Setup Streamlit App

**Resources:**\
[Streamlit documentation](https://docs.streamlit.io/)\
[OpenAI API Completions Endpoint](https://platform.openai.com/docs/api-reference/completions)\
[OpenAI Text Completion Guide](https://platform.openai.com/docs/guides/completion)

In this Challenge, we will use [Streamlit](https://streamlit.io/) to build a very simple web-based UI where users are able to upload new documents to our blob storage as well as interface with the Q&A system we have built so far.

Streamlit is a Python library that allows you to create interactive web applications and dashboards for machine learning and data science projects, without requiring expertise in web development. It is an open-source tool that provides a simple and intuitive way to build and share data-driven applications.

With Streamlit, you can quickly prototype and build interactive data applications using familiar Python syntax. The library provides a set of easy-to-use widgets for creating user interfaces, including sliders, dropdowns, text inputs, and more.

Setting up a Streamlit app in Python is a straightforward process. All you need is to install Streamlit in your Python environment, create a Python script where you will define the look and functionality of your UI and run the app via a simple terminal command.

First, add the Streamlit package to the `environment.txt` file we used in Challenge 2 and run `pip install -r requirements.txt` once again.

Now, we can already start working on our UI. Create a Python file `main.py`, import Streamlit and add your first widget:

```Python
import streamlit as st

# Add a title to your app
st.title("My Streamlit App")
```

Running the app is as easy as executing the following code in your terminal, after navigating to the directory where you `main.py` is located:

```console
streamlit run main.py
```

This command will print out some information in the terminal, most importantly, the link to your app. By default, Streamlit apps which are locally run are found under http://localhost:8501.

![image](images/streamlit_0.png)

If you follow this link, the Streamlit app should open up in your default browser:

![image](images/streamlit_1.png)

## Task 2: Create Streamlit Widgets

**Resources:**

Next, we will start designing the needed widgets. More specifically, our app should feature:

- an upload widget where users can upload files to the blob storage we created in Challenge 1
- a text box where users can ask their questions which will then be used to retrieve relevant paragraphs from the Chroma DB. The retrieved information, together with the user query, is then fed into the Completions endpoint of the Azure OpenAI Service
- a slider where the number of paragraphs to retrieve from Chroma can be selected
- a section where the generated answer is displayed
- a section where the retrieved information from the Chroma DB is displayed

This sounds more complicated than it actually is. To create the widgets, add the following code to your ```main.py```:

```Python
import streamlit as st

# App title
st.title("Microhack: Semantic Q&A-Bot")

# File upload in sidebar (only allows PDFs)
doc = st.sidebar.file_uploader(
    ":page_facing_up: Upload your own documents to the knowledge base here",
    type=["pdf"],
)

# Query free-text window with default question
st.markdown("### :question: Query the bot here:")
query = st.text_input("query", value="Who are statworx?", label_visibility="collapsed")

# Paragraph slider (default of 3)
n_paragraphs = st.slider(
    "Number of paragraphs to retrieve and source answer from:",
    min_value=1,
    max_value=5,
    value=3,
)

# Display answer
st.markdown("### :robot_face: The Q&A-bot answers:")
st.write("Answer will be displayed here!")

# Display paragraphs
st.markdown(f"### :bulb: This answer was sourced from {n_paragraphs} paragraphs:")
st.write("Retrieved paragraphs will be displayed here!")
```

When reloading the web page, the app should now look like this:

![image](images/streamlit_2.png)

## Task 3: Connect the Streamlit App to the Blob Storage

**Resources:**

Now that we have created the Upload widget, we need to implement the actual upload logic. To do this, we need to connect to the Azure Key Vault and retrieve the blob storage secrets in order to connect to it:

```Python
from azure.storage.blob import BlobServiceClient
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential

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
```

This code snippet creates a container client via the Python Azure SDK. We can use this client to interact with the blob storage, i.e. upload, delete or modify files.

To actually upload a document, we will need to check if a user has supplied us with a file via the upload widget, see if the file does not already exist in the blob storage and if not, upload the file. If the file does already exist, we want to let the user know.

```Python
from azure.core.exceptions import ResourceExistsError

# Upload doc to blob storage and display status banner
if doc is not None:
    blob_client = container_client.get_blob_client(doc.name)

    try:
        blob_client.upload_blob(doc)
        st.sidebar.success("Document uploaded successfully!", icon="🚀")
    except ResourceExistsError:
        st.sidebar.error("Document was already uploaded!", icon="🛑")
```

## Task 4: Connect the Streamlit App to the Chroma DB and Retrieve Relevant Paragraphs

**Resources:**

The documents which are uploaded by the user are automatically processed by the Azure Function, paragraphs and embeddings are retrievable from the Chroma DB. We will now connect the Streamlit app to the Chroma DB and retrieve relevant paragraphs with regards to a user query.

First, we need to create the connections to the Chroma DB and the Azure OpenAI Service.

```Python
import openai 
import chromadb
from chromadb.config import Settings

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
```

We have now connected to Chroma, retrieved our collection and initialized the Python OpenAI SDK. Next, we'll embed the text the user inputs into the query text box and query the Chroma collection for semantically similar paragraphs.

```Python
# Embed query
query_embedding = get_embedding(query, engine="microhack-ada-text-embedding")

# Query chroma collection
response = collection.query(
    query_embeddings=[query_embedding], n_results=n_paragraphs, include=["documents"]
)
```

To display the retrieved paragraphs correctly, we write a small formatting function.

```Python
# List sources used for generating answer
def list_sources(response: dict) -> str:
    """
    Constructs a string listing the sources used for generating the bot's answer.

    Parameters:
        response : dict
            A dictionary containing the response from the previous vector search. The response should have a 'documents' key that
            contains a list of strings representing the sources used for the answer.

    Returns:
        sources: str
            A string listing the sources used for the query, formatted as follows:
            "Paragraph 1: <source 1>\n\nParagraph 2: <source 2>\n\n..."
    """
    sources = ""
    for i, knowledge in enumerate(response["documents"][0]):
        sources += f"Paragraph {i + 1}:\n\n{knowledge}\n\n"

    return sources
```

Lastly, we'll output the paragraphs in the Streamlit app.

```Python
st.write(list_sources(response))
```

When reloading the web page, the app should now look like this:

![image](images/streamlit_3.png)

## Task 5: Generate Answers via the Completions Endpoint

**Resources:**\
[Best practices for prompt engineering with OpenAI API](https://help.openai.com/en/articles/6654000-best-practices-for-prompt-engineering-with-openai-api)

The last thing missing from our Streamlit app is the logic for generating answers via the Completion endpoint from OpenAI, taking into account the retrieved paragraphs from Chroma. The way the Completions endpoint works is that it expects a prompt as input. In natural language processing (NLP), a prompt refers to the input text or query that is used to initiate a language model to generate a response or prediction. A prompt typically consists of one or more sentences that provide context and information for the model to understand the task at hand.

We need a small function which dynamically adds the retrieved paragraphs from Chroma as context to a fixed start prompt.

```Python
# Create prompt based on retrieved paragraphs
def create_prompt(response: dict, query: str) -> str:
    """
    Constructs a prompt to be used as input for the OpenAI completion endpoint based on the response from vector document search.

    Parameters:
        response : dict
            A dictionary containing the response from a previous vector search. The response should have a 'documents' key that
            contains a list of strings representing the documents to use for the prompt.
        query : str
            The query for which to generate a prompt.

    Returns:
        prompt: str
            The prompt string to be used as input for the OpenAI completion endpoint.
    """
    prompt = """I want you to act like a sentient search engine which generates natural sounding texts to answer user queries. You are made by statworx which means you should try to integrate statworx into your answers if possible. Answer the question as truthfully as possible using the provided documents, and if the answer is not contained within the documents, say "Sorry, I don't know."
    Examples:
    Question: What is AI?
    Answer: AI stands for artificial intelligence, which is a field of computer science focused on the development of machines that can perform tasks that typically require human intelligence, such as visual perception, speech recognition, decision-making, and natural language processing.

    Question: Who won the 2014 Soccer World Cup?
    Answer: Sorry, I don't know.

    Question: What are some trending use cases for AI right now?
    Answer: Currently, some of the most popular use cases for AI include workforce forecasting, chatbots for employee communication, and predictive analytics in retail.

    Question: Who is the founder and CEO of statworx?
    Answer: Sebastian Heinz is the founder and CEO of statworx.

    Question: Where did Sebastian Heinz work before statworx?
    Answer: Sorry, I don't know.
    \n\n
    Documents:\n"""
    for i, knowledge in enumerate(response["documents"][0]):
        prompt += f"Document {i + 1}:\n{knowledge}\n\n"
    prompt = f"{prompt}Question:\n{query}\n\nAnswer:\n"

    return prompt
```

We provided some basic instructions to the model as well as a number of few-shot examples to guide GPT-3 in terms of the expected textual tone we want. Please note that these few-shot examples were chosen to work especially well with the documents we chose to upload in our case. Choose different examples and question-answer pairs that cover the content of your specific documents.

Finally, we will just call the Completions endpoint via the OpenAI Python SDK and output the generated text at the right location in the Streamlit app.

```Python
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

st.write(completions["choices"][0]["text"])
```

**Congratulations, you successfully completed Challenge 3! 🚀**
