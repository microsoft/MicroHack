# Payments
The payments are generated based on the extracted Sales Order Headers. 
The underlying logic we used :

`paymentDate = BillingdocumentDate + PayOffset +/- random(PayOffsetVariance)`.

In our example the Payment Offset and Payment Offset Variance is depending on the CustomerGroup in the Sales Order Header.

In order to upload the payments to cosmosDB, you can either :

* upload a pregenerated file. The provided file is generated from Sales Orders availabla in S4/HANA Fully Activated Appliance - 1909.
* use a Spark program to generate the payments based upon extract Sales Orders (see [Payment Generation](generatePayments.md))
* Create you own program

## Payment upload from pregenerated file
We used Azure Cosmos DB as container for the Payments. You need to create a Synapse Pipeline to pick up the generated Payments and import them in a Cosmos DB Collection.

* Pre-generated payment data files for different SAP CAL images are available at : [paymendData](../data/)
* This file needs to be copied to a directory on for example Azure Data Lake. A Synapse pipeline can pick up the payments from there and copy them to CosmosDB

### Pipeline Setup
* When the Terrafrom scripts are executed, an Azure Synapse is deployed with an underlying Azure Data Lake. In this datalake you can create a directory to store the paymentData csv file. You can do this from the Azure Synapse Workspace

<img src="../images/paymentsSetup/azdlDirectory.jpg">

>Note : When you generate your own payments, you'll need to setup a similar pipeline.

#### Source Setup - Azure Data Lake
* Create a Linked Service to connect to Azure Data Lake
You can do this by selecting `New Integration dataset`. 

<img src="../images/paymentsSetup/newIntegrationDataSet.jpg">

* Enter a name for you Integration DataSet
* Enter 'DelimitedText' as format
* Import Schema : None

<img src="../images/paymentsSetup/createIntegrationDS.jpg">

* In the created Integration DataSet
    * Select `Semicolon` as Column Delimiter
    * Select `First Row as Header`

<img src="../images/paymentsSetup/paymentIDS.jpg">

* Use the `Preview Data`to test your Integration DataSet

* Publish the Integration Dataset
<img src="../images/paymentsSetup/publishDS.jpg">

#### Sink Setup - CosmosDB
The terraform scripts have created a CosmosDB account with a SQL Database `SAPS4D` and Container `paymentData`for the payments.

* Create a Linked Service to connect CosmosDB
    * Select `Azure CosmosDB (SQL API)`
    * Enter a name for your Linked Service and select the cosmosDB details from your subscription
    <img src="../images/paymentsSetup/cosmosDB_LS.jpg">

>Note : later on you can resuse this Linked Service to extract the payments from CosmosDB

* Create an Integration Dataset
    * Select `Azure CosmosDB (SQL API)`
    AzureCosmosDBSQLAPI.jpg
    * Enter a name for your Integration Dataset
    * Select your Linked Service created earlier
    <img src="../images/paymentsSetup/paymentsCosmos_IDS.jpg">

* Create a pipeline to copy the data from Azure Data Lake to CosmosDB
    * In your Azure Synapse Workspace, select `Integrate`and `+ > New Pipeline`
    <img src="../images/paymentsSetup/createPipeline.jpg">
    
    * Enter a name in the `properties`tab
    <img src="../images/paymentsSetup/pipelineName.jpg">
    
    * Use the `Copy data`activity
    <img src="../images/paymentsSetup/copyDataAction.jpg">

    * Source
    <img src="../images/paymentsSetup/paymentsSource.jpg">

    * Sink
    <img src="../images/paymentsSetup/paymentsSink.jpg">

    * Publish and trigger the pipeline
    <img src="../images/paymentsSetup/publishDS.jpg">
    <img src="../images/paymentsSetup/triggerNow.jpg">

* Verify the result in cosmosDB
    * Switch to your cosmosDB in the Azure Portal

    * Select `Data Explorer`
    <img src="../images/paymentsSetup/cosmosDBDataExplorer.jpg">
    
    * Select your db, payment container
    
    * select `items`
    <img src="../images/paymentsSetup/cosmosDBContents.jpg">

If you want to generate your own payments, switch to [Payment Generation](generatePayments.md)



