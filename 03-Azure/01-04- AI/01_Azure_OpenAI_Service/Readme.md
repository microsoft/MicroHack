# **Master Template MicroHack**

- [**Master Template MicroHack**](#master-template-microhack)
- [MicroHack introduction and context](#microhack-introduction-and-context)
- [Objectives](#objectives)
- [Prerequisites](#prerequisites)
- [Lab environment for this MicroHack](#lab-environment-for-this-microhack)
  - [Architecture](#architecture)
- [MicroHack Challenges](#microhack-challenges)
  - [Challenge 1 - Deploy the Lab environment](#challenge-1---deploy-the-lab-environment)
    - [Goal](#goal)
    - [Task 1: Deploy Baseline](#task-1-deploy-baseline)
    - [Task 2: Verify baseline](#task-2-verify-baseline)
- [Challenge 2 : Name..](#challenge-2--name)
    - [Goal](#goal-1)
    - [Task 1:](#task-1)
    - [Task 2:](#task-2)
    - [Task 3:](#task-3)
    - [Task 4:](#task-4)
- [Challenge 3 : Name ...](#challenge-3--name-)
    - [Goal](#goal-2)
    - [Task 1:](#task-1-1)
    - [Task 2:](#task-2-1)
    - [Task 3:](#task-3-1)
    - [Task 4:](#task-4-1)
- [Finished? Delete your lab](#finished-delete-your-lab)

# MicroHack introduction and context

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

# Objectives

After completing this MicroHack you will:

- Know how to build an AI-powered Q&A bot using Azure services.
- Understand how text embeddings can be used to find relevant passages in unstructured text documents.
- Have an functional Q&A service that takes your own documents as inputs and can be interacted with through a clean UI.

# Prerequisites

In order to use the MicroHack time most effectively, the following tools and services should be set up prior to starting work on the challenges and their task:

- Azure Subscription
- Resource Group
- Visual Studio Code + Azure Extension
- Azure CLI
- Git
- Azure Blob Storage
- Azure Functions
- Azure Elastic Cloud Service
- Azure Form Recognizer
- Azure OpenAI Service

Permissions for deployment:

- Contributor on your Resource Group

With these pre-requisites in place, you can focus on building familiarity with Azure's OpenAI Service that facilitates working with the product, rather than spending unnecessary time repeating relatively simple tasks such as setting up a Storage Account.

# Lab environment for this MicroHack

The challenges of this MicroHack can be completed in any development environment, as long as the following tools are installed properly and fully functional:

- Azure CLI
- Git

We recommend using (Visual Studio Code)[https://code.visualstudio.com/] as a text editor with the following extensions:

TODO: SPECIFY FINAL EXTENSIONS USED DURING DEV
- Python extension
- Azure extensions (which?)

## Architecture

At the end of this MicroHack your base lab build looks as follows:

![image](Path to the architecture)

# MicroHack Challenges 

## Challenge 1 - Deploy the Lab environment

### Goal 

The goal of this exercise is to deploy...

### Task 1: Deploy Baseline

We are going to use a predefined ARM template to deploy the base environment. It will be deployed in to *your* Azure subscription, with resources running in the your specified Azure region.

To start the ARM deployment, follow the steps listed below:

- Login to Azure cloud shell [https://shell.azure.com/](https://shell.azure.com/)
- Ensure that you are operating within the correct subscription via:

`az account show`

- Clone the following GitHub repository 

`git clone Link to Github Repo `

### Task 2: Verify baseline

Now that we have the base lab deployed, we can progress to the ... challenges!


# Challenge 2 : Name..

### Goal

### Task 1: 

### Task 2: 

### Task 3: 

**Explain the background...**

### Task 4: 

Before proceeding to challenge 3, ...

# Challenge 3 : Name ...

### Goal

### Task 1: 

### Task 2: 

### Task 3: 

**Explain the background...**

### Task 4: 

# Finished? Delete your lab


Thank you for participating in this MicroHack!
