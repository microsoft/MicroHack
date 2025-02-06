# Deploy Synapse Workspace

## Introduction
In this part we'll create the Synapse Workspace.

## Creation
* Create a Synapse Analytics Workspace

<img src="images/synapsews/synapsewsservice.jpg">

Enter the following settings :
### Basics :
* Resource Group
* Workspace Name
* Data Lake Storage : Select an existing Data Lake or create a new one
* File System Name : Select an exising File System or create a new one

<img src="images/synapsews/synapsewsservice_basics.jpg">

### Security :
* Admin Username & Password : this will be there userId and password for the related SQL Pools.

<img src="images/synapsews/synapsewsservice_security.jpg">

Other settings can remain as default.

# After deployment :
* Create a `staging` directory within the Synapse Azure Data Lake container. This directory is used for storage of temporary files during data upload to Synapse.

<img src="images/synapsews/stagingDirectory.jpg">

* Create a new SQL Pool\
Choose `DW100c` as performance level (to save on costs).

<img src="images/synapsews/createSQLPool.jpg">

Continue to the [Synapse configuration](SynapseWorkspace.md)