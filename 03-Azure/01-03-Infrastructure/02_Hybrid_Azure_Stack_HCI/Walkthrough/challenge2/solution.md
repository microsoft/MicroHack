# Walkthrough Challenge 2 - Management / control plane fundamentals at the beginning

Duration: 30 minutes

[Previous Challenge Solution](../challenge1/solution.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge3/solution.md)

## Prerequisites

Please ensure that you successfully passed [challenge 1](../../Readme.md#challenge-1---create-your-first-virtual-machines-on-azure-stack-hci) before continuing with this challenge.

### Task 1: Create necessary Azure resources

1. Sign in to the [Azure Portal](https://portal.azure.com/).

2. Create a new Resource Group called *AzStackHCI-MicroHack-Azure* in your favorite Azure region.

![image](./img/1_CreateResourceGroup.png)

3. Create a new Azure Automation Account called *mh-automation* with default settings in the same Resource Group.

![image](./img/2_CreateAutomationAccount.png)
![image](./img/3_CreateAutomationAccount.png)
![image](./img/4_CreateAutomationAccount.png)

4. Create a new Log Analytics Workspace called *mh-la* with default settings in the same Resource Group.

![image](./img/5_CreateLAW.png)
![image](./img/6_CreateLAW.png)

### Task 2: Configure Log Analytics

1. Navigate to the Log Analytics Workspace and open *Agents configuration* in the left navigation pane.

![image](./img/7_agent_configuration.png)

2. Select *Add windows event log* and add the *System* logs to the workspace. Hit apply.

![image](./img/8_win_system.png)

3. Navigate to Syslog in the top navigation pane, select *Add facility* and add *syslog* logs to the workspace. Hit apply.

![image](./img/9_syslog.png)

### Task 3: Create a new service principal for Azure Arc
 
1. Navigate to *Azure Arc* using the top search bar and select *Service Principals* in the left navigation pane.

![image](./img/10_arc_dashboard.png)

2. Configure the service principal with the following settings:

![image](./img/11_New_Arc_SP.png)

3. Please wait a few seconds until the creation of the Service Principal is complete. You should see the following:

![image](./img/12_secret.png)

`❗Hint: Take a note of the Client ID and Secret before you proceed!`

### Task 4: Prepare the Azure Arc environment

1. Navigate to *Servers* in the left navigation pane and select *Add*.

![image](./img/16_Arc_Add.png)

2. Select *Add multiple servers* and hit *Generate script*.

![image](./img/17_Arc_GenerateScript.png)

3. Select *Next*.

![image](./img/18_Arc_GenerateScript.png)

4. Select the Azure resource group called *AzStackHCI-MicroHack-Azure* and ensure that Windows is selected.  

![image](./img/19_Arc_GenerateScript.png)

5. Select the Service Principal that was created in [Task 3](#task-3-create-a-new-service-principal-for-azure-arc) and hit *Next*.

![image](./img/20_Arc.png)

6. Skip the tags section and hit *Next*.

7. Select "Register" to enable your subscription for Azure Arc and copy the generated script. Please insert your retrieved secret from [Task 3](#task-3-create-a-new-service-principal-for-azure-arc) into the script and save it in your favorite text editor.

![image](./img/21_download_script.png)

8. Please repeat steps 1-7 for Linux servers and make sure to select Linux as the Operating System in step 4.

![image](./img/22_Arc_Generate_Script.png)

### Task 5: Assign Azure Policy Initiative to your Azure Arc resource group

1. Navigate to *Policy* using the top search bar and select *Assignments* in the left navigation pane.

![image](./img/23_azure_policy.png)

2. Select *Assignments* in the left navigation pane and go to *Assign initiative*

![image](./img/24_assignments.png)

3. In this section you can now configure the assignment with the following settings and create the assignment:

- Scope: Please select the resource group called *AzStackHCI-MicroHack-Azure*
- Basics: Please search for *Enable Azure Monitor for VMs* and select the initiative.
- Parameters: Please select your Log Analytics workspace.

![image](./img/25_basic_settings_initiative.png)

![image](./img/25_basic_settings_initiative.png)

4. Please wait a few seconds until the creation of the assignment is complete. You should see that the initiative is assigned. Every new Azure Arc Server will now automatically install the necessary agents. 

You successfully completed challenge 2! 🚀🚀🚀