# Walkthrough Challenge 1 -  Use Azure Form Recognizer, Python and Azure Functions to process stored documents

Duration: **TBD**

**[Home](../../Readme.md)** - [Next Challenge Solution](../challenges/challenge-2/solution.md)

## Prerequisites

In order to complete Challenge 1, make sure to complete the Development Setup under [Link](../../Readme.md) and read through the [General Prerequisites](../../Readme.md#prerequisites). It is assumed that you already created an Azure Account with a valid Azure Subscription and a Resource Group for the MicroHack.

## Task 1: Create a Storage Account

**Resources:**

[Create Storage Account | Microsoft Learn](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-create?tabs=azure-portal)\
[Quickstart: Create, download, and list blobs with Azure CLI](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-cli)\
\
A storage account provides a unique namespace in Azure for your data. Every object that you store in Azure Storage has an address that includes your unique account name. The combination of the account name and the Blob Storage endpoint forms the base address for the objects in your storage account.\
\
Under the MicroHack Resource Group, search for *storage account* in the search bar.
![image](./images/storage_account_0.png)

On the Storage Account subpage, either click on *+ Create* at the top of the page or on *Create storage account*.
![image](./images/storage_account_1.png)

On the configuration page, the correct Azure Subscription and Resource Group should have been automatically selected under *Project Details*. Under *Instance Details* you need to name the Storage Account and select a deployment region. Here, we selected **Germany West Central** since statworx is located in Frankfurt, Germany. It is, however, up to you where you want your Storage Account to be located. The selections for **Performance** and **Redundancy** are also up to you. Since we are only using this Storage Account for showcase purposes, low latency and high redundancy are not of primary concern to us. After you have given your storage account a name, selected the right deployment region and selected suitable performance and redundancy options, click on **Review**. We do not modify the standard selections under the tabs **Advanced**, **Networking**, **Data protection**, **Encryption** or **Tags**. If you are handling sensitive data or have specific networking needs, please consult the official Azure resources.
![image](./images/storage_account_2.png)

On the **Review** page, click on *Create* if you are happy with your configuration. It should take you to the deployment page of the storage account.
![image](./images/storage_account_3.png)

After the deployment page shows that the deployment was completed, click on *Go to resource*.
![image](./images/storage_account_4.png)

You are now seeing the main page of your newly created storage account. From the sidebar, under **Data storage**, select *Containers*.
![image](./images/storage_account_5.png)

A container organizes a set of blobs, similar to a directory in a file system. At the top of the page, click on *+ Container*. A sidebar should appear. Give your container a suitable name. Under *Public access level*, select the access level suitable for your use case and click on *Create*.
![image](./images/storage_account_6.png)

Your newly created container should now be selectable. You can now upload data by clicking on your container and selecting *Upload* at the top of the page.
![image](./images/storage_account_7.png)

If you want to use the Azure CLI for creating the storage account and uploading files, please refer to the resource at the beginning of the task.

## Task 2: Setup Azure Form Recognizer

**Resources:**

[Azure Form Recognizer Documentation](https://learn.microsoft.com/en-us/azure/applied-ai-services/form-recognizer/?view=form-recog-3.0.0)\
[Azure Form Recognizer Pricing](https://azure.microsoft.com/en-us/pricing/details/form-recognizer/#pricing)\
\
Azure Form Recognizer is a cloud-based Azure Applied AI Service that uses machine-learning models to extract key-value pairs, text, and tables from your documents. Form Recognizer analyzes your forms and documents, extracts text and data, maps field relationships as key-value pairs, and returns a structured JSON output.\
\
Under the MicroHack Resource Group, search for *form recognizer* in the search bar.
![image](./images/form_recognizer_0.png)

On the Form Recognizer subpage, either click on + Create at the top of the page or on Create form recognizer.
![image](./images/form_recognizer_1.png)

On the configuration page, the correct Azure Subscription should have been automatically selected under *Project Details*. You need to specify the Resource Group under which you want the Form Recognizer to be situated. Under *Instance Details* you need to name the Form Recognizer Service, select a deployment region and decide on the pricing tier. We once again selected **Germany West Central** and gave the Form Recognizer Service a fitting name. When it comes to the pricing tier, you can decide to use the free tier which lets you process 500 document pages per month with a limit of 20 API calls per minute or the paid tier. Please refer to the pricing page at the top of this task for more details. Since we are exclusively using the Form Recognizer for demonstration purposes, we decided to use the free tier.
After you have given your Form Recognizer Service a name, selected the right resource group, deployment region and decided on a suitable pricing tier, click on **Review + create**. We once again do not modify the standard selections under the tabs **Network**, **Identity** or **Tags**. If you are handling sensitive data or have specific networking needs, please consult the official Azure resources.
![image](./images/form_recognizer_2.png)

On the Review page, click on Create if you are happy with your configuration. It should take you to the deployment page of the Form Recognizer Service.
![image](./images/form_recognizer_3.png)

After the deployment page shows that the deployment was completed, click on Go to resource.
![image](./images/form_recognizer_4.png)

You are now seeing the main page of your newly created Form Recognizer Service. From the sidebar, under Resource Management, select Keys and Endpoint.
![image](./images/form_recognizer_5.png)

Copy the key and endpoint values and paste them in a convenient location, such as a Microsoft Notepad, for now. You'll need the key and endpoint values to connect your application to the Form Recognizer API. We will save these values in an Azure Key Vault in the next step. Make sure to keep these values in a private location - API keys are sensitive values and should not be stored in a public place such as a Git repository.
![image](./images/form_recognizer_6.png)

## Task 3: Setup Azure Key Vault and Save Form Recognizer Keys
**Resources:** \
[About Azure Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/general/overview)\
[Quickstart: Create a key vault using the Azure CLI](https://learn.microsoft.com/en-us/azure/key-vault/general/quick-create-cli)\
[Assign a Key Vault access policy](https://learn.microsoft.com/en-us/azure/key-vault/general/assign-access-policy?tabs=azure-portal)

Azure Key Vault is a cloud service used to manage keys, secrets, and certificates. Key Vault eliminates the need for developers to store security information in their code. It allows you to centralize the storage of your application secrets which greatly reduces the chances that secrets may be leaked.

![image](images/key_vault_0.png)

![image](images/key_vault_1.png)

![image](images/key_vault_2.png)

![image](images/key_vault_3.png)

![image](images/key_vault_4.png)

![image](images/key_vault_5.png)

![image](images/key_vault_6.png)

![image](images/key_vault_7.png)

![image](images/key_vault_5.png)

![image](images/key_vault_8.png)

![image](images/key_vault_9.png)

![image](images/key_vault_10.png)

![image](images/key_vault_11.png)

## Task 4: Setup ElasticSearch/OpenSearch

## Task 5: Create the Azure Function

## Task 6: Write the Python Processing Script

## Task 7: Test your Pipeline

You successfully completed Challenge 1! 🚀
