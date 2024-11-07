# Walkthrough Challenge 1 - Prerequisites and Landing Zone

Duration: 30 minutes

## Prerequisites

- Please ensure that you successfully verified the [General prerequisits](../../Readme.md#general-prerequisites) before continuing with this challenge.
- The Azure CLI is required to deploy the Bicep configuration of the Micro Hack.
- Download the *.bicep files from the [Resources](../../resources) to your local PC.

### **Task 1: Deploy the Landing Zone for the Micro Hack**

- Open the [Azure Portal](https://portal.azure.com) and login using a user account with at least Contributor permissions on a Azure Subscription. Start the Azure Cloud Shell from the Menu bar on the top.

![image](./img/CS1.png)

> [!NOTE]
> You can also use your local PC but make sure to install [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli).

- If this is the first time that Cloud Shell is beeing started, create the required Storage Account by selecting *Bash* and clicking on *Create storage* and wait until the Storage Accounts has been created.

![image](./img/CS1-1.png)

![image](./img/CS2.png)

- Make sure to select *Bash*.

![image](./img/CS3.png)

- Clone the MicroHack Github repository using the `git clone https://github.com/microsoft/MicroHack.git` command.

![image](./img/CS4.png)

- Change into to Migrate & Modernize Microhack directory of the cloned repository using the `cd MicroHack/03-Azure/01-03-Infrastructure/06_Migration_Datacenter_Modernization/resources` command.

![image](./img/CS5.png)

- Execute `az deployment sub create --name "$(az ad signed-in-user show --query userPrincipalName -o tsv | cut -d "@" -f 1 | tr '[:upper:]' '[:lower:]')-$(cat /proc/sys/kernel/random/uuid)" --location swedencentral --template-file ./main.bicep --parameters currentUserObjectId=$(az ad signed-in-user show --query id -o tsv) --parameters userName="$(az ad signed-in-user show --query userPrincipalName -o tsv | cut -d "@" -f 1 | tr '[:upper:]' '[:lower:]')"`

![image](./img/CS6.png)

- Wait for the deployment to finish. You can view the deployment from the Azure portal by selecting the Azure Subscription and click on *Deployments* from the navigation pane on the left.

![image](./img/CS7.png)

> [!NOTE]
> Please note that the deployment may take up to 10 minutes.

### **Task 2: Verify the deployed resources**
The bicep deployment should have created the following resources

- source-rg Resource Group containing the follwing resources
    + Virtual Network *source-vnet*
    + Virtual Machine *Win-fe1* with installed web server on a Windows Server System
    + Virtual Machine *Lx-fe2* with installed web server on a REHL System
    + Public Load Balancer *plb-frontend* with configured backend pool containing *frontend1* and *frontend2* VM
    + Azure Bastion *source-bastion*
    + Azure Key Vault *source-kv-* containing username and password for VM login
   
- destination-rg Resource Group containing the follwing resources
    + Virtual Network *destination-vnet*
    + Azure Bastion *destination-bastion*
    
The deployed architecture looks like following diagram:
![image](./img/Challenge-1.jpg)

### **Task 3: Verify Web Server availability**

- Open *source-rg* Resource Group
- Select *plb-frontend* Load Balancer
- Navigate to *Frontend IP configuration* under *Settings* section on the left
- Note and copy public IP address of *LoadBalancerFrontEnd*
- Open web browser and navigate to http://LoadBalancerFrontEnd-IP-Address
- A simple website containing the server name of the frontend1 or frontend2 VM should be displayed

You successfully completed challenge 1! 🚀🚀🚀

 **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-2/solution.md)
