# Walkthrough Challenge 2 - Setting up a functional Pipeline

Duration: **TBD**

**[Home](../../Readme.md)** - [Next Challenge Solution](../challenges/challenge-2/solution.md)\

## Prerequisites

In order to complete Challenge 2, make sure to complete the Development Setup under [Link](../../Readme.md) and work through the tasks laid out in Challenge 1. It is assumed that you already created an Azure Storage Account, Form Recognizer, Key Vault, Elastic Cloud and Azure Function set up. 

## Task 1: Implement the Azure Form Recognizer in the Azure Function

**Resources:**

[Use Azure Functions and Python to process stored Documents](https://learn.microsoft.com/en-us/azure/applied-ai-services/form-recognizer/tutorial-azure-function?view=form-recog-3.0.0)\

After setting up the individual services needed for this MicroHack, we are now moving on to writing the python script that handles the data processing within our defined Azure Function, once the function has been triggered. 

## Task 2: Generate Text Embeddings via the Azure OpenAI Service in the Azure Function

**Resources:**

Under your Resource Group, search for *openai* in the search bar and select the **Azure OpenAI** service.

![image](./images/openai_0.png)

This will take you to the **Cognitive Services | Azure OpenAI** subpage, either click on *+ Create* at the top of the page or on *Create Azure OpenAI*.

![image](./images/openai_1.png)

On the configuration page, select the correct Azure Subscription under *Project Details*. You need to specify the Resource Group under which you want the Azure OpenAI resource to be situated. Under *Instance Details* you need to select a deployment region, name the Azure OpenAI service and decide on the pricing tier. We selected **West Europe**, gave the Azure OpenAI service a fitting name and chose the default pricing tier.

The next step is to click on **Review + create**. We once again do not modify the standard selections under the tabs **Network**, **Identity** or **Tags**. If you are handling sensitive data or have specific networking needs, please consult the official Azure resources.

![image](./images/openai_2.png)

Next, Azure is prompting us to give the resource some tags that make it easier to differentiate between multiple instances of the same service. Which tags you want to set and how to name their values is entirely up to you. 

![image](./images/openai_3.png)

On the Review page, click on Create if you are happy with your configuration. It should take you to the deployment page of the Azure OpenAI service. Deployment might take an unexpectedly long time for this particular resource - do not be surprised if it takes over an hour finish deployment. 

![image](./images/openai_4.png)


![image](./images/openai_5.png)

![image](./images/openai_6.png)

![image](./images/openai_7.png)

![image](./images/openai_8.png)

![image](./images/openai_9.png)
## Task 3: Create the ElasticSearch Index

**Resources:** 
[Create Index API](https://www.elastic.co/guide/en/elasticsearch/reference/current/indices-create-index.html)\

In order to write documents to our Elasticsearch service, we need to set up a so-called index first. Think of an index as the elastic version of a database, where our text data is stored in an unstructured way. To interact with our Elasticsearch cluster, we can use HTTP requests to read, create, delete and write to an Elasticsearch index. 

From the overview page of your Elastic Cloud service, navigate to the **Kibana** link that will take you to the dedicated Kibana instance that is used to monitor and manage your Elastic Cloud deployment. 

![image](./images/elasticsearch_0.png)

Toggle the menu on the left side of the page and navigate to the **Management** section at the very bottom. From there select the **Dev Tools** rider, which will take you to a developer console that you can use to interact with your elasticsearch cluster. 

![image](./images/elasticsearch_1.png)

From there you can now create a new Index for your Elasticsearch cluster that can then store and search through your documents. To do so, write a HTTP PUT request that specifies the index name you would like to create. We decided to call our index `qa-knowledge-base`. The complete PUT request thus becomes: `PUT /qa-knowledge-base`. Execute your request by clicking the green **send** button on the top-right corner of your console. 

If successful, the output window to the right will indicate that your request was acknowledged and display the name of your newly created Elasticsearch index. 

![image](./images/elasticsearch_2.png)

We can also test the success of your our request manually by requesting the names of all the currently existing indexes of our Elasticsearch cluster. To do so, we use a GET request: `GET /_cat/indices`

This prints the name of all currently existing indexes to the output window and adds some additional information such as the number of currently stored documents per index. It appears that our cluster now hosts multiple indexes: the one that we just created, as well as some default indexes that we do not need to interact with for the time being. 

![image](./images/elasticsearch_3.png)

## Task 4: Write the Extracted Paragraphs + Embeddings to the Azure Elastic Service

**Resources:**

## Task 5: Test the Azure Function Locally

**Resources:**

## Task 6: Deploy the Azure Function

**Resources:**


You successfully completed Challenge 2! 🚀
