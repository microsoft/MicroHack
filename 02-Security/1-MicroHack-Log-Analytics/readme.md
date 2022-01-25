# **How to collect all my security relevant log data? (Log Analytics)**

# Contents

[MicroHack introduction and context](#microhack-introduction-and-context)

[Objectives](#objectives)

[Prerequisites](#prerequisites)

[Lab environment for this MicroHack](#lab-environment-for-this-microhack)

[Challenge 1: Deploy the Lab environment](#challenge-1---deploy-the-lab-environment) 

[Challenge 2: Collect logs from Windows VM](#challenge-2--collect-logs-from-windows-vm)

[Challenge 3: Collect logs from Linux VM](#challenge-3-collect-logs-from-linux-vm)

[Challenge 4: First query with KQL](#challenge-4-first-query-with-kql)

[Challenge 5: Onboard storage account to LA Workspace](#challenge-5-onboard-storage-account-to-log-analytics-workspace)

[Challenge 6: Onboard activity logs to LA Workspace](#challenge-6-onboard-azure-activity-logs)

[Challenge 7 : Link Automation account to LA Workspace](#challenge-7-link-automation-account-to-la-workspace)

# MicroHack introduction and context

This MicroHack scenario walks through the use of Log Analytics and with a focus on security log collection. Specifically, this builds up to include working with an existing infrastructure to get an overview how to collect relevant security logs. 

The overall architecture is designed for the Security MicroHacks in this repository. This means that some parts of the architecture of the MicroHacks contain e.g. only placeholders for services or elements that will be added in the following MicroHacks. To get a comprehensive learning experience it makes sense to start with the first MicroHack and then work your way through piece by piece. 

## Architecture for this MicroHack Series (Overall architecture at the end)
![image](images/Architecture.svg)

This lab is not a full explanation of Azure Monitor & Log Analytics as a technology, please consider the following articles required pre-reading to build foundational knowledge.

- [Overview Log Analytics ](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-tutorial)
- [Azure Monitor Agent](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-overview)

### Optional (read this after completing this lab to take your learning even deeper!)
- [Azure Monitor design principles and best practices](Link to Martina & Mo´s Repo)
- [Should I switch to the new Azure Monitor agent?](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-overview#should-i-switch-to-azure-monitor-agent)

# Objectives 

After completing this MicroHack you will:

- Know how to build a basic log analytics workspace design and connect a new workspace to relevant services
- Understand default security log configuration
- Have an overview of why log analytics is important to build an overall security baseline
- Understand the basics from log analytics and how it relates to the Azure security products

# Prerequisites

In order to use the MicroHack time most effectively, the following tasks should be completed prior to starting the session.

With these pre-requisites in place, we can focus on building the differentiated knowledge in Azure Monitor and Log Analytics that is required when working with the product, rather than spending hours repeating relatively simple tasks such as setting up Log Analytics.

### At the end of this section your base lab build looks as follows:

![image](images/FirstMicroHackLA.svg)

# Lab environment for this MicroHack

The Lab starts simply with an understanding of Log Analytics. 
The following components are needed for this: 

- Resource Group 
- Central Log Analytics Workspace
- Linux Virtual Machine
- Windows Virtual Machine
- Storage Account Archiving 
- Storage Account 
- Automation Account

Permissions for the deployment: 
- Contributor on your Resource Group
- Azure AD rights for Activity Log connection

Now it should be clear which components we need and in order not to lose any time let's start directly with the first challenge. 

# MicroHack Challenges 

# Challenge 1 - Deploy the Lab environment

## Goal

The goal of this exercise is to deploy the Lab environment and get some hands on with experience with the Azure Cloud shell. 

## Task 1: Login to Azure Cloud shell

1. Login to Azure cloud shell [https://shell.azure.com/](https://shell.azure.com/)
2. If you don´t have a storage account mounted, choose you subscription and create a new one --> otherwise move on with the next step

![Cloudshellnewstorage](images/Cloudshellcreatestorage.png)


![Terminalconnected](images/Terminalconnected.png)

3. Ensure that you are operating within the correct subscription via. Please copy the command and execute it in you active Azure Cloud Shell session. 

```
az account show
```

If output shows "Welcome to Azure Cloud Shell" you are good to go. Move on with the next task. 

## Task 2: Deploy the resource group 

Please copy the command and execute it in the already existing Azure Cloud Shell session. 

```

az group create --name rg-MicroHack-AzureSecurity --location westeurope

```


💡 Keep in mind: If you want to change the name of the resource group please feel free to do it. But please be aware of that the name is used in some other commands later on.

## Task 3 : Deploy centralized Log Analytics Workspace

In this task you will deploy the centralizied Log Analytics Workspace for our lab environment. Please be aware of that there some design principles out there that will help you to get an understanding of the best practices. For this MicroHack series it is good enough to have one LA workspace up and running. To move on please copy the command and execute it in your active Cloud Shell session. 

```

az monitor log-analytics workspace create -g rg-azuresecurity-microhacks -n microhack-workspace -l westeurope

```

🔦 Here we shed some light on the best practices and design principles about Log Analytics: Click here 🔦 [Azure Monitor design principles and best practices](Link to Martina & Mo´s Repo)

<!--
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fnilsbankert%2FMicroHacks-Microsoft-Security%2Fmain%2F1-MicroHacks-Azure-Security%2F1-MicroHack-Log-Analytics%2FARM%2520Templates%2FLogAnalticsWorkspace.json%3Ftoken%3DAHOMOJBICIGLSYUNSOUPCG3AII2PY)

-->


## Task 3: Deploy Virtual Machines

In the next steps you will deploy a virtual machine setup. This machines will later be used for onboarding to the relevant Azure monitoring and security services. 

🔒 After executing the command you will be asked for a password. Please save this password in secure environment or keep it in mind. We will need it in the next challenges. 

### Deploy Linux Virtual Machine with CLI 

In this task you will deploy a virtual machine with an Ubuntu Image. Pleas copy the command and execute in your Azure Cloud Shell session. 

```
az vm create -n Linux -g rg-MicroHack-AzureSecurity --image UbuntuLTS --admin-username microhack
```

### Deploy Windows Virtual Machine with CLI 

In this task you will deploy a virtual machine with an Windows Image. Please copy the command and execute in your Azure Cloud Shell session. 

```
az vm create \ --resource-group rg-MicroHack-AzureSecurity \ --name Windows \ --image win2019datacenter \ --admin-username microhack
```

✅ Congratulations our lab environment is ready and now you will get some hands on with the virtual machines and the relevant log collection configuration. 

# Challenge 2 - Collect logs from Windows virtual machine

## Goal

In this challenge you will connect a Windows virtual machine running in Azure with a centralized Log Analytics workspace for collecting important Windows Logs. After completing the challenge the Windows virtual machine will continuously send relevant logs to the Log Anayltics workspace for further analysis.

## Task 1: Configure Log Analytics to collect relevant Windows logs

Please go to the Azure Portal and open your Log Analytics Workspace that was created at the beginning of this MicroHack. Select "Agents configuration" and click on "add windows event log" to add "System" and "Application" log the the collected data. 

![alt text](images/law-agent-config-win.png "Agents configuration")

In addition to the Event Logs we want to collect some performance metrics from the virtual machine. Please select the "Windows performance counters" tab and click on "Add recommended counters". 

The basic configuration to collect relevant data from the connected Windows virtual machines is completed. 

`❗ Hint: In a real-world scenario you might add additional performance counters based on your scenario. If you have additional software on the virtual machine that integrates with Windows performance counters you can add them to Log Analytics as well.`  


## Task 2: Onboard the Windows virtual machine to Log Analytics

Please select "Virtual machines" under "Workspace Data Sources" in the Log Analytics workspace. You should see two virtual machines running Windows and Linux that are currently not connected. 

![alt text](images/vm-overview-not-connected.png "VMs not connected")

Click on the Windows virtual Machine and connect it to the Log Analytics workspace. The virtual machine is now connected to the Log Analytics workspace. 

![alt text](images/vm-overview-connected.png "Windows VM connected")

Immediately after connecting the Windows virtual machine to the Log Analytics workspace the agents inside the Windows virtual machine will start to collect data from the configured data sources and send it to the workspace.

`❗ Hint: In general it's recommended to onboard virtual machines to Log Analytics via Azure Policy.`  

## Task 3: Login to the Windows virtual machine

In order to generate some security events please login to the Windows virtual machine via RDP with valid credentials. 


# Challenge 3: Collect logs from Linux VM 

## Goal

In this challenge you will connect a Linux VM running in Azure with a centralized Log Analytics Workspace for collecting the syslog logs.  

## Task 1: Configure Log Analytics to collect relevant Windows logs

Please navigate to "Agents configuration" and click on "Syslog" in the Log Analytics workspace. Select "Add facility" and choose "syslog" in the list of available sources and hit "Apply".

![alt text](images/law-agent-config-linux.png "Agents configuration")

The basic configuration to collect the syslog events from the Linux virtual machine is completed. 

`❗ Hint: In a real-world scenario you might add additional performance counters based on your scenario. If you have additional software on the virtual machine that integrates with Windows performance counters you can add them to Log Analytics as well.`  


## Task 2: Onboard the Linux virtual machine to Log Analytics

Please select "Virtual machines" under "Workspace Data Sources" in the Log Analytics workspace. Connect the Linux virtual machine to the workspace. 

![alt text](images/vm-overview-all-connected.png "All VMs connected")

After connecting the Linux virtual machine to the Log Analytics workspace the agents inside the Linux virtual machine will start to collect data from syslog and send it to the workspace.

`❗ Hint: In general it's recommended to onboard virtual machines to Log Analytics via automation.`  

# Challenge 4: First query with KQL

## Goal

In this challenge we will execute our first queries to get an overview about the collected logs from our Windows and Linux virtual machines. The goal is to explore the different event sources and get some insights about our virtual machines. 

## Task 1: Query successful Windows logins

Remember that you successfully logged in to the Windows virtual machine in [Challenge 2](#challenge-2---collect-logs-from-windows-vm)? Let's see if we can find the event in Log Analytics. 

Please go to the Log Analytics workspace and select Logs to open the query editor. 
```
SecurityEvent
| where EventID == "4624"
| project TimeGenerated, Account, Computer, Activity
```
![alt text](images/succesful-login-query-results.png "All succesfull logins to Windows")

## Task 2: Query failed Windows logins

Log Analytics offers different built-in queries to help you getting started. In this task we will have a look at all failed Windows authentications reported to the Log Analytics workspace. Please select "Queries" and search for "Windows failed logins". Click on the item under the security pillar and run the query. 

![alt text](images/failed-login-query-results.png "All failed logins to Windows")

`❗ Hint: Depending on the pace of some port scanners you should see a lot of failed login requests with different user names.`  

All alarm bells should start to ring now. There is definitly something malicious going on and let's gather some further details. Edit the query and add the source IP-Address of the request to the query to see who is actually trying to login.  

```
SecurityEvent
| where EventID == 4625
| summarize count() by TargetAccount, Computer, IpAddress, _ResourceId
```

![alt text](images/failed-login-query-results2.png "All failed logins to Windows with IP-Address")

No surprise - all requests originate from the internet. Bad actors try to connect via RDP using password spray attacks to our Windows virtual machine. 

❗ Important note: It's highly recommended to protect your Windows and Linux virtual machines with Network Security Groups if you need to assign a public IP-address. Consider using [just-in-time access](https://docs.microsoft.com/en-us/azure/security-center/security-center-just-in-time) to secure SSH and RDP. The virtual machines in this MicroHack are only for demonstration purposes accessible over the internet.  

## Task 3: Create an alarm if too many Windows logins fail from a certain IP-Address 

to be continued...

# Challenge 5: Onboard storage account to Log Analytics Workspace

## Goal

In this challenge you will onboard an Azure Storage account to Log Analytics. As a result, important log entries like changes to blobs inside the storage account will be send to Log Analytics. 

## Task 1: Configure diagnostic settings of the storage account

Please navigate to the storage account with the prefix loganalytics that was created earlier in Challenge 1 as part of the lab deployment. Now select the "Diagnostic settings (preview)" and click on "blob". In order to complete this task configure the diagnostic settings to send the logs to your Log Analytics workspace. 

![alt text](images/storage-account-diagnostic-settings.png "Diagnostic settings")

## Task 2: Upload some files and delete them afterwards

Use the Storage Explorer in the Azure Portal to upload some files for testing purposes into the storage account. After successfully uploading the files you can delete some of these files to generate some additional log entries.

![alt text](images/upload-file-to-azure-storage.png "Upload files to Azure storage")

## Task 3: Query Log Analytics workspace for events in your storage account

Go back to the Log Analytics workspace and open the query editor. Let's list all file uploads and deletions in the storage account. Execute the following query: 

```
StorageBlobLogs
| where OperationName contains "PutBlob" or OperationName contains "DeleteBlob"
| project TimeGenerated, CallerIpAddress, AuthenticationType, AccountName, OperationName, Uri
```

You shoud see a list of all your activities incl. the upload and deletion of blobs. 

![alt text](images/storage-account-query-results.png "Results in Log Analytics")

## Task 4: 

Before proceeding to challenge 6, ...

# Challenge 6: Onboard Azure Activity Logs

This challenge is a key for your overall security baseline. The configuration should be created at the beginning of every Azure enrollment or subscription. 

## Goal

After the configuration is in place you can gain insights into subscription-level events. This includes such information as when a resource is modified or when a virtual machine is started. 

## Task 1: Connect Activity Logs to Log Analytics workspace

Open the Azure Monitor threw the Azure Portal. Click on Activity Log and choose Diagnostic settings. 

![AzureMonitorActivity](images/AzureMonitor_ActivityLogToLogAnalytics.png)




Select **"Add diagnostic setting"**, choose a name for the configuration, tick all log categories and send everything to the log analytics workspace that we have created in challenge 1. Click on Save and move on with the next task. 



![AzureMonitorActivity](images/AzureMonitor_ActivityLogToLogAnalytics2.png)

![AzureMonitorActivity](images/AzureMonitor_ActivityLogToLogAnalytics3.png)

💡 Only new Activity log entries will be sent to the Log Analytics workspace, so perform some actions in your subscription that will be logged such as starting or stopping a virtual machine or creating or modifying another resource. You may need to wait a few minutes for the diagnostic setting to be created and for data to initially be written to the workspace. After this delay, all events written to the Activity log will be sent to the workspace within a few seconds.

## Task 2: Retrieve Log Data hands on

Select Logs in the Azure Monitor menu. If the scope isn't set to the workspace you created, then click select scope and locate it.

In the query window type in the following queries and click run to execute. Please again be aware of that only new Activity log entries will be sent to the Log Analytics workspace, so perform some actions in your subscription that will be logged such as starting or stopping a virtual machine or creating or modifying another resource.

- **"AzureActivity"** 
- **"AzureActivity | summarize count() by CategoryValue"** 

![AzureMonitorActivity](images/AzureMonitor_ActivityLogToLogAnalytics4.png)

💡 If you want to learn more about Azure Monitor and the language KQL which is used in Azure Monitor see here: 

- [Design a holistic monitoring strategy on Azure](https://docs.microsoft.com/en-us/learn/modules/design-monitoring-strategy-on-azure/)
- [Analyze query results using KQL](https://docs.microsoft.com/en-us/learn/modules/analyze-results-kusto-query-language/)

 
# Challenge 7: Link Automation Account to LA Workspace

## Goal

## Task 1: 

## Task 2: 

## Task 3: 

**Explain the background...**

## Task 4: 

Before proceeding to challenge 8, ...

# Challenge 8: (Optional) Govern everything with Azure Policy 

## Goal

## Task 1: 

## Task 2: 

## Task 3: 

**Explain the background...**

## Task 4: 

Before proceeding to challenge 8, ...

# Finished? Delete your lab

Thank you for participating in this MicroHack!
