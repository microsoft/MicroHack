# Walkthrough Optional Challenge 6 - Post migration 

Duration: 40 minutes

## Prerequisites

Please make sure that you successfully completed [Challenge 5](../challenge-5/solution.md) before continuing with this challenge.



## **Task 1: Enable Azure Update Manager**

In [Challenge 5](../challenge-5/solution.md) you migrated servers to Azure. Now you will enable Azure Update Manager, that is a unified service to help manage and govern updates for all your machines (running a server operating system). Update Manager work both for Windows And Linux and machine in Azure or connected by Azure Arc

To enable the Update Manger components, open the portal and seach for  *Update Manager* in the top search bar.  Then click *Azure Update Manager*.

![image](./img/azureupdatemanageroverview.png)

In the left meny click **Resources** and click **Machines**. Now you will see all Azure VMs and all Arc enabled VMs, even if the machines are managed by Update Manger or not.

![image](./img/azureupdatemanager_machines.png)

To enable Update Manager, we fist we need to configure assessment and patch orchestration, that will be done by sellect current VMs by check the checkbox for the VM, and then select *Settings** in the top menu and then select **Update settings** .

Assessmnet
change **Periodic assmessment** value to ***enable** This will enable assessmnet of patches every 24 hours

Patch Orchstration

choose **Customer Managed Schedules** and click **Save**
 
Patch orchestration option provides:

*Customer Managed Schedules* — enables schedule patching on your existing VMs. The new patch orchestration option enables the two VM properties - Patch mode = Azure-orchestrated and BypassPlatformSafetyChecksOnUserSchedule = TRUE on your behalf after receiving your consent.

*Azure Managed - Safe Deployment* — for a group of virtual machines undergoing an update, the Azure platform will orchestrate updates. (not applicable for Arc-enabled server). The VM is set to automatic VM guest patching.(i.e), the patch mode is AutomaticByPlatform. There are different implications depending on whether customer schedule is attached to it or not. For more information, see the user scenarios.
    Available *Critical* and *Security* patches are downloaded and applied automatically on the Azure VM using automatic VM guest patching. This process kicks off automatically every month when new patches are released. Patch assessment and installation are automatic, and the process includes rebooting the VM as required.

*Windows Automatic Updates (AutomaticByOS)* - When the workload running on the VM doesn't have to meet availability targets, the operating system updates are automatically downloaded and installed. Machines are rebooted as needed.

*Manual updates* - This mode disables Windows automatic updates on VMs. Patches are installed manually or using a different solution.

*Image Default* - Only supported for Linux Virtual Machines, this mode uses the default patching configuration in the image used to create the VM.


![image](./img/azureupdatemanager_settings.png)

## **Task 2: Create a patching schedule and assign it**

After we have enabled the periodic and patch orecestration. We need to create a schedule for the patching, or a *maintenance configuration* as is calling in Azure.

Select the current Virtual machines, and click **Schedule Updates** in the menu. Now a blade to create a new *maintenance configuration* will open. Give the schedule a *name* and place it in the desrtination *resource group*, maintenace scope should be set to *Guest*

![image](./img/createmainconf.png)

click **add a schedule**, here you can configure start date, Manitenance windows and how often the patching will happens hourly, daily, weekly or monthlly. then click **Save**. for the task we will not wait for the schudule to happen so, click **Review and Create** and **Create**
 


## **Task 3: Enable Defender for Cloud for Server**

In [Challenge 5](../challenge-5/solution.md) we migrated two servers to Azure. The servers are already protected by the basic services of Defender for Cloud. In this challenge, we'll improve significantly the protection level by activating advanced services such as "Cloud Security Posture Management (CSPM)" and "Cloud Workload Protection (CWP)" (Defender for Server).

To enable the advanced Defender for Cloud components, open the portal and select *Defender for Cloud*.  Under *Management*, select the *Environment Settings* to define the Defender for Cloud setting for the subscription.

![image](./img/Def-environment-settings.jpg)

In the settings, enable *Defender CSPM* and *Defender for Server* plans to better protect the migrated servers from threats. After enabling the plans, use the "Settings" link for both plans and verify that all features are enabled. Finally *Save* the new configuration.

![image](./img/Def-environment-settings.jpg)

Verify the *Defender CSPM* Settings & monitoring details

![image](./img/Def-CSPM-monitoring.png)

Verify the *Defender for Server* Settings & monitoring details 

![image](./img/Def-DefenderServerSettings.png)

> [!NOTE]
> It takes a few minutes for the new settings to be applied and for more agents to be installed on the servers.

## **Task 4: Check if Defender for Endpoint is active on the virtual machines**

To check if *Defender for Server* was successfully activated on the virtual machines, open the portal and select *Virtual Machines* and select a Windows Server. Under *Operations'* select to run a command and chose to run a PowerShell script/command.

![image](./img/VM-runps.png)

Run the *Get-MpComputerStatus* cmdlet to get the status of antimalware software installed on the virtual machine.

![image](./img/vmatpstatus.png)

On a Linux machine you run a shell script instead of PowerShell - the commandline *mdatp health* will return the health of the *Defender for Endpoint* on a Linux box.

![image](./img/vmlinuxatpstatus.png)


## **Task 5: Check if a virus attack is reported in Azure**

In the next step, we check whether the infection with malware is reported to Azure, so that appropriate reactions can be triggered based on an alert - e.g. inform administrators, open an incident or follow up on the problem and initiate appropriate measures or react to such incidents with automatic rules.

Open the portal and select *Virtual Machines* and select a Windows Server. Select *Connect* and establish a connection with the virtual machines using *Bastion*.

![image](./img/vmconnect.png)

The European Institute for Computer Antivirus Research (EICAR) and Computer Antivirus Research Organization (CARO), provide a harmless test file to test the response of computer antivirus programs. Instead of using real malware, which could cause real damage, this test file allows people to test anti-virus software without having to use a real computer virus. Open the following UIRL in a browser in the virtual machine: https://www.eicar.org/download-anti-malware-testfile/ 

Scroll down a bit until you can see the 68 character long EICAR string.  

![image](./img/vm-eicarstring.png)

We will not try to download a test-file from the website, because this will be blocked by the browser already. Instead, we will create a new file on the virtual machine and paste the EICAR string into and try to safe the file. 

Select the EICAR String and copy it into the clipboard. Create a new file on the desktop and paste the EICAR string into the file.

![image](./img/vmnewfile.png)

![image](./img/vmfile.png)

Try to safe the file. Defender for Endpoint will trigger - it'll quarantine the file and and display a warning on the local server.

![image](./img/vmthreat.png)

Next, we will double-check if this alert was forwarded to Azure. Open the portal and select *Defender for Cloud* and select *Security Alerts*. EICAR malware detections are reported with severity "Informational" - to include these alerts in the view you need to change the filter: Add severity "informational" in the filter settings - and the security alerts will be displayed.

![image](./img/DefSecAlert.png)

## **Task 4: Explore *Defender for Cloud* proactive security advice**

The challenges in this Microhack were designed to be simple and implemented straight forward as virtual machines in a single subscription. The implementation of a secure and scalable landing zone according to the best practices from the *Cloud Adaption Framework* ([What is an Azure landing zone? - Cloud Adoption Framework | Microsoft Learn](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)) was waived for the sake of simplicity. 

On the other hand, this now causes *Defender for Cloud* making a number of recommendations on how to proactively improve the security of the environment.
To view general security recommendations for the managed virtual machines, please open the portal and select Defender for Cloud. Under Security Posture, you can view the recommendations in detail.

![image](./img/secpost01.png)

Click on Security Posture to view a list of recommendations for the various resource being used.

![image](./img/secpost02.png)

The list of recommendations for your environment will look slightly different than in this screenshot, because the resource that you've installed might experience different vulnerabilities. Review the recommendations and click them to view the details. In the details for each recommendation, you'll find a description, you can assign the recommendation to a user for implementation or you can create an exempt. 

Go back to *Defender for Cloud* and click on *Attack path analysis* - this will provide you an overview about specific vulnerabilities in your environment and how they can be utilized by attackers to compromise your environment. 

![image](./img/secpost03.png)

In this Microhack, we deployed virtual machines that use public IP addresses and are directly exposed to the internet - this is straight forward, but for sure not a best practice. Click on one of the *Attack paths* to learn more about the details of this attack vector.

![image](./img/secpost04.png)


## **Task 4: Enable and configure Copilot for Security**

Sign in to Copilot for Security (https://securitycopilot.microsoft.com).




You successfully completed challenge 6! 🚀🚀🚀

🚀🚀🚀 **!!!Congratulations!!! - You successfully completed the MicroHack. You can now safley remove the *source-rg* and *destination-rg* Resource Groups.** 🚀🚀🚀

 **[Home](../../Readme.md)** 