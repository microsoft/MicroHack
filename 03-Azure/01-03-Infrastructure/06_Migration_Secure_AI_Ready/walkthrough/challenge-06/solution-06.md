# Walkthrough Optional Challenge 6 - Secure on Azure

[Previous Challenge Solution](../challenge-05/solution-05.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-07/solution-07.md)

Duration: 40 minutes

## **Task 1: Enable Defender for Cloud for Servers**

In [Challenge 5](../challenge-05/solution-05.md) we migrated two servers to Azure. The servers are already protected by the basic services of Defender for Cloud. In this challenge, we'll significantly improve the protection level by activating advanced services such as "Cloud Security Posture Management (CSPM)" and "Cloud Workload Protection (CWP)" (Defender for Servers).

To enable the advanced Defender for Cloud components, open the portal and select *Defender for Cloud*. Under *Management*, select *Environment settings* to define the Defender for Cloud settings for the subscription.

![image](./img/Def-environment-settings.jpg)

In the settings, enable the *Defender CSPM* and *Defender for Servers* plans to better protect the migrated servers from threats. After enabling the plans, use the *Settings* link for both plans and verify that all features are enabled. Finally, click *Save*.

![image](./img/Def-environment-settings.jpg)

Verify the *Defender CSPM* settings and monitoring details.

![image](./img/Def-CSPM-monitoring.png)

Verify the *Defender for Servers* settings and monitoring details.

![image](./img/Def-DefenderServerSettings.png)

> [!NOTE]
> It takes a few minutes for the new settings to be applied and for more agents to be installed on the servers.

## **Task 2: Check if Defender for Endpoint is active on the virtual machines**

To check whether *Defender for Servers* was successfully activated on the virtual machines, open the portal and select *Virtual Machines*. Select a Windows Server, and then use *Run command* under *Operations* to run a PowerShell script or command.

![image](./img/VM-runps.png)

Run the *Get-MpComputerStatus* cmdlet to get the status of antimalware software installed on the virtual machine.

![image](./img/vmatpstatus.png)

On a Linux machine, run a shell script instead of PowerShell. The *mdatp health* command returns the health of Defender for Endpoint on the Linux machine.

![image](./img/vmlinuxatpstatus.png)


## **Task 3: Check whether a malware alert is reported in Azure**

In the next step, check whether a simulated malware detection is reported to Azure. An alert can notify administrators, open an incident, trigger a follow-up, or initiate an automated response.

Open the portal and select *Virtual Machines*. Select a Windows Server, select *Connect*, and establish a connection to the virtual machine using *Bastion*.

![image](./img/vmconnect.png)

The European Institute for Computer Antivirus Research (EICAR) and Computer Antivirus Research Organization (CARO) provide a harmless test file for testing antimalware software. Instead of using real malware, which could cause damage, this file lets you test the software safely. Open the [EICAR anti-malware test file page](https://www.eicar.org/download-anti-malware-testfile/) in a browser on the virtual machine.

Scroll down a bit until you can see the 68-character-long EICAR string.

![image](./img/vm-eicarstring.png)

Do not download a test file from the website because the browser will block it. Instead, create a new file on the virtual machine, paste the EICAR string into it, and try to save the file.

Select the EICAR string and copy it into the clipboard. Create a new file on the desktop and paste the EICAR string into the file.

![image](./img/vmnewfile.png)

![image](./img/vmfile.png)

Try to save the file. Defender for Endpoint will detect and quarantine it, and then display a warning on the local server.

![image](./img/vmthreat.png)

Next, verify that the alert was forwarded to Azure. Open the portal, select *Defender for Cloud*, and then select *Security Alerts*. EICAR detections are reported with the severity *Informational*. Add *Informational* to the severity filter to display these alerts.

![image](./img/DefSecAlert.png)

## **Task 4: Explore *Defender for Cloud* proactive security advice**

The challenges in this Hack were designed to be simple, with virtual machines deployed in a single subscription. For simplicity, the lab omits the secure, scalable landing zone recommended by the *Cloud Adoption Framework* ([What is an Azure landing zone? - Cloud Adoption Framework | Microsoft Learn](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)).

As a result, *Defender for Cloud* makes several recommendations for proactively improving the security of the environment.
To view general security recommendations for the managed virtual machines, please open the portal and select Defender for Cloud. Under Security Posture, you can view the recommendations in detail.

![image](./img/secpost01.png)

Click *Security Posture* to view recommendations for the resources in use.

![image](./img/secpost02.png)

The recommendations for your environment might differ from the screenshot because the resources you've deployed might have different vulnerabilities. Review the recommendations and click each one to view its details. You can assign a recommendation to a user for implementation or create an exemption.

Go back to *Defender for Cloud* and click *Attack path analysis*. This view provides an overview of specific vulnerabilities in your environment and how attackers could use them to compromise it.

![image](./img/secpost03.png)

In this Hack, we deployed virtual machines that use public IP addresses and are directly exposed to the internet. This approach is straightforward but isn't a best practice. Click one of the *Attack paths* to learn more about the attack vector.

![image](./img/secpost04.png)


You successfully completed Challenge 6.

Continue to Challenge 7, select the migrated IIS or Apache workload, and configure intelligent observability. Do not remove `destination-rg`.
