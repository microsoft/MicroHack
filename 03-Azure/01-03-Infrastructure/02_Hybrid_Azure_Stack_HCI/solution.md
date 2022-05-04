# **MicroHack Azure Stack HCI - Part I**

[toc]




# Challenge 2
### Task 1: Create necessary Azure Resources 

- Azure RG
- Automation Account
- Log Analytics Workspace

![image](./img/9_CreateResourceGroup.png)

![image](./img/10_CreateAutomationAccount.png)

![image](./img/11_CreateAutomationAccount.png)

![image](./img/12_CreateAutomationAccount.png)

![image](./img/13_CreateLAW.png)

![image](./img/14_CreateLAW.png)

Add Windows event logs
Add Syslog

### Task 2: Create Azure Policy for onboarding Azure Arc enabled Servers

- Azure Policy Asssignment

Azure Policy: initiative Enable Azure Monitor for VMs

Hint: Permissions Contronutor Policy
Alternative approach: manual deployment in VMs

### Task 3: Prepare the Azure Arc environment

- Setup Arc
- Service Principal
- generate Scripts


![image](./img/15_Arc_Page.png)

![image](./img/16_Arc_Add.png)

![image](./img/17_Arc_GenerateScript.png)

![image](./img/18_Arc_GenerateScript.png)

![image](./img/19_Arc_GenerateScript.png)

![image](./img/20_Arc.png)

![image](./img/21_Serviceprincipal.png)

![image](./img/22_Serviceprincipal_secret.png)

![image](./img/23_Add_Servers_Arc.png)

![image](./img/24_Add_Servers_Download.png)


challenge 3



### Task 1: Windows VMs

![image](./img/25_onboarding_script_win.png)
![image](./img/26_onboarding_success.png)


### Task 2: Linux VMs

![image](./img/27_generate_script_linux.png)
![image](./img/28_edit_linux_script.png)
![image](./img/29_onboarding_success_linux.png)


Be aware to block Azure IDMS endpoint! 

### Task 3: Enable Update Management

![image](./img/33_enable_update_mgmt_allVMs.png)

https://docs.microsoft.com/en-us/azure/azure-monitor/logs/computer-groups#creating-a-computer-group

Save as function
schedule update (your local time + 6 min)

### coffee break

### Task 4: Enable Inventory

### Task 5: Enable VM Insights

![image](./img/34_Enable_VM_Insights.png)

### Coffee break


# challenge 4

### Task 1: Create Key Vault 

![image](./img/40_Create_KeyVault.png)
Create Key Vault with default settings

### Task 2: Assign permissions to Key Vault

![image](./img/41_Assign_KeyVault_permissions.png)

### Task 3: Create Secret

![image](./img/42_Create_Secret.png)

### Task 4: Retrieve secret via Bash

ChallengeTokenPath=$(curl -s -D - -H Metadata:true "http://127.0.0.1:40342/metadata/identity/oauth2/token?api-version=2019-11-01&resource=https%3A%2F%2Fmanagement.azure.com" | grep Www-Authenticate | cut -d "=" -f 2 | tr -d "[:cntrl:]")
ChallengeToken=$(cat $ChallengeTokenPath)
if [ $? -ne 0 ]; then
    echo "Could not retrieve challenge token, double check that this command is run with root privileges."
else
    curl -s -H Metadata:true -H "Authorization: Basic $ChallengeToken" "http://127.0.0.1:40342/metadata/identity/oauth2/token?api-version=2019-11-01&resource=https%3A%2F%2Fvault.azure.net"
fi

Extract Refresh Token

curl 'https://mh-keyvault0815.vault.azure.net/secrets/kv-secret?api-version=2016-10-01' -H "Authorization: Bearer $token"

### Optional: Certificate IIS