# Challenge 1 - Create Oracle Database@Azure resources

**[Home](../Readme.md)**

## Goal

Prepare the landing zone and subscription so an Oracle Database@Azure (ODAA) environment can be purchased and deployed, ending with an Autonomous Database ready for later challenges.

## 💰 Purchase Oracle Database@Azure (Prerequisite)

To purchase Oracle Database@Azure, contact the Oracle sales team or your Oracle sales representative for a sale offer. Oracle Sales creates an Azure private offer in Azure Marketplace for your instance of the service. After an offer is created for your organization, you can accept the offer and complete the purchase in the marketplace in the Azure portal. For more information about Azure private offers, see Overview of the commercial marketplace and enterprise procurement.

Billing and payment for the service is processed through Azure. Payment for Oracle Database@Azure counts toward Microsoft Azure Consumption Commitment (MACC). Existing Oracle Database software customers can use a bring your own license (BYOL) option or an unlimited license agreement (ULA). On your regular invoice for Azure, charges for Oracle Database@Azure appear with charges for your other Azure Marketplace services.

> ⚠️ **IMPORTANT**: In this Microhack the Oracle Database@Azure has been already purchased.


## Actions

* Document the Azure subscription, resource group, network, and identity requirements that must be in place prior to provisioning ODAA resources.
* Initiate creation of an Autonomous Database through the Azure portal and OCI console, noting every configuration choice and the administrator credentials you define.
* Record connection details, regional placement, and any integration points that will be required by downstream workloads in subsequent challenges.

## Success criteria

* You have validated that all prerequisite Azure infrastructure (resource group, networking, identity, RBAC) is ready for the deployment.
* You have provisioned an Autonomous Database instance in Oracle Database@Azure and retained the administrator credentials and connection endpoints for later use.
* You have documented configuration decisions and outstanding follow-up actions for the team.

## Learning resources

* https://docs.oracle.com/en-us/iaas/Content/database-at-azure/overview.htm
* https://docs.oracle.com/en-us/iaas/Content/database-at-azure/azucr-create-autonomous-database.html