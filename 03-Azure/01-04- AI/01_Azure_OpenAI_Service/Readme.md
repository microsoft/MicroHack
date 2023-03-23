# **Master Template MicroHack**

- [**Master Template MicroHack**](#master-template-microhack)
  - [MicroHack introduction and context](#microhack-introduction-and-context)
  - [Objectives](#objectives)
  - [Prerequisites](#prerequisites)
  - [Lab environment for this MicroHack](#lab-environment-for-this-microhack)
  - [Architecture](#architecture)
  - [MicroHack Challenges](#microhack-challenges)
    - [Challenge 1 - Set up required services and tools](#challenge-1---set-up-required-services-and-tools)
    - [Goal](#goal)
    - [Task 1: Create a Storage Account](#task-1-create-a-storage-account)
    - [Task 2: Setup Azure Form Recognizer](#task-2-setup-azure-form-recognizer)
    - [Task 3: Setup Azure Key Vault and Save Form Recognizer Keys](#task-3-setup-azure-key-vault-and-save-form-recognizer-keys)
    - [Task 4: Setup Elastic Cloud](#task-4-setup-elastic-cloud)
    - [Task 5: Create the Azure Function](#task-5-create-the-azure-function)
    - [Task 6: Write the Python Processing Script](#task-6-write-the-python-processing-script)
    - [Task 7: Test your Pipeline](#task-7-test-your-pipeline)
    - [Challenge 2 : Name](#challenge-2--name)
    - [Goal](#goal-1)
    - [Task 1:](#task-1)
    - [Task 2:](#task-2)
    - [Task 3:](#task-3)
    - [Task 4:](#task-4)
    - [Challenge 3 : Name](#challenge-3--name)
    - [Goal](#goal-2)
    - [Task 1:](#task-1-1)
    - [Task 2:](#task-2-1)
    - [Task 3:](#task-3-1)
    - [Task 4:](#task-4-1)
- [Finished? Delete your lab](#finished-delete-your-lab)

## MicroHack introduction and context

This MicroHack scenario walks through the creation of a Q&A bot using the Azure OpenAI service for building a semantic search pipeline. This Hack focuses on setting up the necessary Azure services as the building blocks of a Q&A bot powered by OpenAI's most recent language models and Azure. It guides you through setting up a robust infrastructure that extracts paragraphs from your raw text documents, stores them in a text data base optimized for search use cases and then leverages the power of Natural Language Processing to find the information you are looking for - all from within Microsoft Azure and requiring minimal coding.

TODO:
![image](Path to the high level architecture)

Semantic search is a more informed way of sifting through documents. Traditional search methods relied on finding lexical overlap between a query and the contents of a document. Semantic search foregoes this approach and instead assumes that language exists in a latent semantic space, where words that are similar in meaning reside close to each other - and those that are different are separated by large distances. Deep neural networks facilitate finding the semantic location of words as they can be trained to translate words into numerical representations of their meanings, called word embeddings, and thus enabling us to measure their distance from each other and draw inference about the relationships amongst each other.

Semantic search uses this technique to find information that is most closely related to a search query, measured as the distance between their respective embeddings. The language models developed by OpenAI are highly proficient at this task. They have been trained on massive amounts of text data from many different contexts, hence they are prodicient at projecting natural language text to a latent, semantic space and are thus well-suited for building AI-powered Q&A applications.

This MicroHack is not an in-depth explanation of word embeddings as a technology, so please consider the following articles as required pre-reading to build foundational knowledge about the technology that enables finding semantic similarity between words, paragraphs and entire documents:

* https://openai.com/blog/introducing-text-and-code-embeddings
* https://platform.openai.com/docs/guides/embeddings/what-are-embeddings
* https://learn.microsoft.com/en-us/azure/cognitive-services/openai/concepts/understand-embeddings
* https://medium.com/@statworx_blog/whats-cooking-at-statworx-ecd863edfabe

## Objectives

After completing this MicroHack you will:

- Know how to build an AI-powered Q&A bot using Azure services.
- Understand how text embeddings can be used to find relevant passages in unstructured text documents.
- Have an functional Q&A service that takes your own documents as inputs and can be interacted with through a clean UI.

## Prerequisites

In order to use the MicroHack time most effectively, the following services should be set up and ready for use prior to starting work on the challenges and their task:

- Azure Account
- Azure Subscription
- Azure Resource Group

Permissions for deployment:

- Contributor on your Resource Group

With these pre-requisites in place, you only need to set up the lab environment before starting to work on the challenges. These are designed for you to build familiarity with Azure's various services that facilitate implementing NLP-products through the use of services such Azure OpenAI, Azure Storage, Azure Functions and Elastic Cloud.

## Lab environment for this MicroHack

The majority of challenges of this MicroHack are completed in the Azure portal, with only a few tasks requiring any code at all. For the few tasks that do require code we suggest you set up a Lab environment that has access to the following tools:

- Azure CLI
  - Find detailed information on installing the Azure CLI in the [official documentation.](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
  - `Homebrew` makes it easy to install the Azure CLI on macOS: `brew install azure-cli`
- Git
  - Make sure that you have [Git installed on your computer](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git). This also enables you to clone the MicroHack repository to your local machine by executing the following command from your Shell:  
  `git clone https://github.com/microsoft/MicroHack.git`

We recommend using [Visual Studio Code](https://code.visualstudio.com/) as a text editor with the following extensions:

TODO: SPECIFY FINAL EXTENSIONS USED DURING DEV

- Python for Visual Code Studio
  - [This guide](https://code.visualstudio.com/docs/python/python-tutorial) walks you through installing a Python interpreter and the extension needed for using VSCode for Python development.
- Azure extensions (which?)

## Architecture

At the end of this MicroHack your base lab build looks as follows:

![image](Path to the architecture)

## MicroHack Challenges

### Challenge 1 - Set up required services and tools

### Goal

The goal of this challenge is to set up all the Azure services and tools that are required for building the backend of a fully functional Q&A chatbot.

### Task 1: Create a Storage Account

In this task you will set up a Storage Account in Azure which contains and manages all of your Azure Storage data objects such as blobs.

### Task 2: Setup Azure Form Recognizer

In this task you will set up the Azure Form Recognizer service, which extracts text from files and helps you turn your documents into data.

### Task 3: Setup Azure Key Vault and Save Form Recognizer Keys

### Task 4: Setup Elastic Cloud

Elasticsearch acts as the data base for storing our text data for this MicroHack. In this task, you will set up the Elastic Cloud service that makes deploying your own Elasticsearch cluster easier than ever.

### Task 5: Create the Azure Function

### Task 6: Write the Python Processing Script

### Task 7: Test your Pipeline

### Challenge 2 : Name

### Goal

### Task 1:

### Task 2:

### Task 3:

**Explain the background...**

### Task 4:

Before proceeding to challenge 3, ...

### Challenge 3 : Name

### Goal

### Task 1:

### Task 2:

### Task 3:

**Explain the background...**

### Task 4:

# Finished? Delete your lab

Thank you for participating in this MicroHack!
