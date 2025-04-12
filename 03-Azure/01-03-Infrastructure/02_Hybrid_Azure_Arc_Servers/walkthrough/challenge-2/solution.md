# Walkthrough Challenge 2 - Use Azure Monitor, Azure Update Management and Inventory for your Azure Arc enabled Servers

Duration: 30 minutes

[Previous Challenge Solution](../challenge-1/solution.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-3/solution.md)

## Prerequisites

Please ensure that you successfully passed [challenge 1](../../Readme.md#challenge-1) before continuing with this challenge.


### Task 1: Create all necessary Azure Resources (Log Analytics workspace)

1. Sign in to the [Azure Portal](https://portal.azure.com/).

2. Create a new Log Analytics Workspace called *mh-arc-servers-automation-law* with default settings in the your Resource Group.

![image](./img/5_CreateLAW.jpg)

***Please note**: For convenience, in this MicroHack create the Log Analytics workspace in the same resource group as you are using for your arc-enabled servers. Reason: The service pricinipal (used for remediation tasks) of the policy will be given the necessary RBAC roles on the scope where the policy is assigned. In this MicroHack we assume that every participant will assign the policy on resource group level. Hence, if the LAW is outside of that scope, you would need to assign the required permissions manually on the LAW.*


### Task 2: Configure Data Collection Rules in Log Analytics to collect Windows event logs and Linux syslog

1. Navigate to the Log Analytics Workspace and open *Agents* in the left navigation pane.

2. Select *Data Collection Rules* followed by a click on *Create* to create Data collection rules. 

![image](./img/2.2_Create_Data_Collection_Rule.png)

3. Name the Data Collection Rule *mh-dcr* select your subscription, set your ressource group and change the Region to *West Europe*. Change Platform Type to *All* and click *Next: Resources* to continue.

![image](./img/2.3_Create_Data_Collection_Rule_Basics.png)

4. Click on *Collect and deliver* as we going to set the scope of resources later on via Azure Policy. Click *Add data source*. For *Data source type* select *Windows Event Logs* and check the boxes of the log levels you would like to collect.

5. Click *Next: Destination* and *Add destination*. As *Destination type* select *Azure Monitor Logs* and in *Account or namespace* pick the Log Analytics workspace your created earlier. Click *Add data source*.

![image](./img/2.5_Create_Data_Collection_Rule_Destination.png)

6. Repeat step 4 & 5 for Linux Syslog and accept the defaults.

7. Create the Data Collection Rule. 


### Task 3: Enable Azure Monitor for Azure Arc enabled Servers with Azure Policy initiative

1. Navigate to *Policy* using the top search bar and select *Assignments* in the left navigation pane.

2. Select *Assignments* in the left navigation pane and go to *Assign initiative*

3. In this section you can now configure the assignment with the following settings and create the assignment:

- Scope: Please select your resource group
- Basics: Please search for *Enable Azure Monitor for Hybrid VMs with AMA* and select the initiative.
- Parameters: Please insert the Resource ID of the Data Collection Rule from Task 2. 
- Remediation: Please select the System assigned identity location according to your resources, e.g. West Europe. Don't check the box for "Create a remediation task" here, as it would only create a remediation task for the first policy within the policy initiative. We will do this in one of the next steps for all policies.
- Click *Review + create* and then *Create*

4. Please wait around 30 seconds until the creation of the assignment is complete. You should see that the initiative is assigned. Every new Azure Arc server will now automatically install the AMA and Dependency agents as well the necessary association with the data collection rule we created in task 2. Be aware that agent installation can take up to 60 Minutes.

![image](./img/3.4_Assign_Policy_Monitor_AMA.png)

5. Important: Both machines were already onboarded earlier. As a result, you need to create a remediation task for each policy in the initiative to apply the policy to your existing Azure Arc Servers. Please select the Policy Assignment and select *Create Remediation Task*.

![image](./img/3.5_Assign_Policy_Monitor_AMA_remidiate.png)

6. Accept the default values, check *Re-evaluate resource compliance before remediating* and repeat the remediation for the following policies:
 - AzureMonitorAgent_Windows_HybridVM_Deploy
 - AzureMonitorAgent_Linux_HybridVM_Deploy
 - DependencyAgentExtension_AMA_Windows_HybridVM_Deploy
 - DependencyAgentExtension_AMA_Linux_HybridVM_Deploy
 - DataCollectionRuleAssociation_Windows
 - DataCollectionRuleAssociation_Linux

![image](./img/3.6_Assign_Policy_Monitor_AMA_remidiate.png)

7. In Policy > Remediation > Remediation Task, verify that all remediation completed successfully:

![image](./img/3.7_Assign_Policy_Monitor_AMA_remidiate.png)

### Task 4: Enable and configure Update Manager

1. Navigate to *Policy* using the top search bar and select *Assignments* in the left navigation pane.

2. Select *Assignments* in the left navigation pane and go to *Assign Policy*

3. In this section you can now configure the assignment with the following settings and create the assignment:

- Scope: Please select your resource group used for arc resources
- Basics: Please search for *Configure periodic checking for missing system updates on azure Arc-enabled servers* and select the policy. As *Assignment name* append *(Windows)* 
- Parameters: Skip, and keep defaults (which targeting Windows guest OS.)
- Remediation: Please select the System assigned identity location according to your resources, e.g. West Europe. 
- Click *Review + create* and then *Create*

4. Please wait a few seconds until the creation of the assignment is complete. You should see that the policy is assigned.

5. Repeat step 3 and 4 for the policy definition *Configure periodic checking for missing system updates on azure Arc-enabled servers*, apply the same configuration as in step 3 but this time unselect the checkbox at *Only show parameters that need input or review*, and change OS Type to *Linux*. Also append *(Linux)* in the *Assignment name* field.

6. Important: Both machines were already onboarded earlier. As a result, you need to create a remediation task to trigger the DeployIfNotExists effect of the policy to your Azure Arc Servers. Please select the policy assignment and select *Create Remediation Task*.

7. Accept the default values, check *Re-evaluate resource compliance before remediating* and repeat the remediation for the following policies:
 - Configure periodic checking for missing system updates on azure Arc-enabled servers (Windows)
 - Configure periodic checking for missing system updates on azure Arc-enabled servers (Linux)

8. Verify that all remediation were successful.

9. Navigate to Azure Arc, select Servers, repeat step 10 for your your Windows and Linux Server.

10. Select Updates. If there are no update information dispayed yet, click *Check for updates* and wait until missing updates appear. Then click on *One-time update* or *Schedule updates* if you would like to postpone the installation to a later point in time. (follow the wizzard).

![image](./img/4.10_Update_Management.png)

11. After applying the updates point-in-time or via scheduler you should see the updates beeing installed on the system.

![image](./img/4.11_Update_Management.png)

### Task 5: Enable Change Tracking and Inventory

To enable change tracking and inventory, we can use the azure portal. There are multiple ways to enable it and the following will describe two possible options. Firstly, it can be enabled for individual arc enabled machines:

1. Select an arc-enabled server in your resource group

2. In the side panel under *Operations*, select > *Inventory* and input the previously created log analytics workspace. You might need to first select the correct azure region to see a list of all log analytics workspaces in that region.

3. Click on *Enable* and wait for the option to complete

4. Repeat the same steps in the interface under *Operations* > *Change Tracking*. Important: If the previous operation from step three did not complete yet, you will recieve an error when you enable the extension. ("Wait, An extension of type AzureMonitorLinuxAgent is still processing. Only one instance of an extension may be in progress at a time for the same resource")

![image](./img/5.1_CTI_individual.png)


Change Tracking and inventory can also be enabled through the portal for for multiple machines at once:

1. Navigate to *Change Tracking and Inventory* using the top search bar and select *Arch enabled Machines* in the filter settings.

1. Use the checkboxes to select all machines you want to enable change tracking for and then click on *Enable Change Tracking & Inventory* in the row over the filter settings.

3. Confirm your selection in the dialogue box. In the next screen of the wizard, make sure to change all the log analytics workspaces to the one you created previously by selecting the right region and picking your LAW from the dropdown. Confirm by clickng on the enable button in the wizard. 

4. Wait for the deployment to finish and verify the machines showing up in the overview in side panel *Inventory*. In the panel *Change tracking*, you will not see any entries, until you start changing files on your previously added servers

![image](./img/5.2_CTI_LAW_selection.png)

### Task 6: Enable VM Insights

1. Navigate to your Virtual Machines, in section *Monitoring* select *Insights* in the left navigation pane.

2. In the *Insights* tab, click the *Enable* button.

3. In the *Monitoring Configuration* form, for *Data collection rule* click the *Create New* link

4. Fill in the *Create new rule* form
- Data collection rule name: Provide a name (MSVMI for VMInsights will be appended automatically) - i.e. *DCR-MicroHack*
- Enable process and dependencies (Map): Check the box
- Subscription: Keep the default
- Log Analytics workspace: Choose the workspace you created in task 1
- Click *Create* button. Then click *Configure* button.

5. For all other VMs you want to enable for VM Insights in that region, repeat step 1 and 2. Then, in the *Monitoring configuration* form, make sure your newly created data collection rule is selected and click configure.

6. Wait for the deployment of the data collection rule to finish. This might take several minutes.


### Coffee Break of 10 minutes to let the data flow between your Virtual Machines and Azure

After your coffee break you should see that the Virtual Machines are reporting their status. You can now check the Update Management for pending updates, verify what software is installed on the machines and get deep insights of the utilization of your Virtual Machines.

You successfully completed challenge 2! 🚀🚀🚀
