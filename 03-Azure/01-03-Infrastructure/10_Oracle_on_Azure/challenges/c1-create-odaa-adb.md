# 🚀 Challenge 1: Create Azure ODAA Resources



## 💰 Purchase Oracle Database@Azure

To use the service, you configure it within your Azure subscription through a process referred to as onboarding. To begin onboard, contact your Oracle representative and request a Private Offer. After you agree on pricing, terms and conditions, you complete the purchase through Azure Marketplace. After the purchase is complete, you link your Azure subscription with an OCI tenancy. This is called multicloud linking.

Learn how to link a new or existing OCI Account to Oracle Database@Azure.

Multicloud Linking means, after you complete Purchase, Oracle sends you an email with the subject line "Action Required: Welcome to New Oracle Cloud Service Subscription(s)." After you receive the email, you can link an OCI account to your Oracle Database@Azure service. Whether you create a new OCI account or link an existing account depends on your situation. Read about both options in the following sections.

Your OCI account is used for the provisioning and management of container databases (CDBs) and pluggable databases (PDBs). Your OCI account also allows Oracle to provide infrastructure and software maintenance updates for your database service.

- [Onboarding Oracle Database@Azure](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/oaaonboard.htm)
- [Linking your Azure subscription with an OCI tenancy](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/onboard-link.htm)

> ⚠️ **IMPORTANT**: In this Microhack the Oracle Database@Azure has been already purchased.

## ⚙️ Provision Oracle Database@Azure by using the Azure portal

You can find your already purchased Oracle Database@Azure service in the Azure portal. 

1. Search for "Oracle" inside the azure portal searchbar on the top.
1. Selecte the "Oracle Database@Azure" service from the search results. 
1. Select "Oracle Autonomous Database" from the left-hand menu.
1. Click on "+ Create Oracle Autonomous Database" button to start the creation of a new Autonomous


When you set up an instance of Oracle Database@Azure, you use both the Azure portal and the Oracle Cloud Infrastructure (OCI) console.
Follow the steps described on the following links: 

> IMPORTANT: Administrator credentials will be defined by the user during the creation of the ADB instance. Remember the password as we will use the same password as for the GoldenGate installation in section 3.

- 📖 [Overview](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/overview.htm)
- 🔧 [Create an Autonomous Database](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/azucr-create-autonomous-database.html)