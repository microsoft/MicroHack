# Walkthrough Challenge 4 - Access Azure resources using Managed Identities from your on-premises servers

Duration: 30 minutes

[Previous Challenge Solution](../challenge-2/solution.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-4/solution.md)

## Prerequisites

Please ensure that you successfully passed [challenge 2](../../Readme.md#challenge-2) before continuing with this challenge.

### Task 1: Check and collect the Log Analytics workspace


### Task 2: Configure Defender for Cloud

Enable Defender for Server
Configure autodeployment of AMA

### Task 3: Check that the server is visible in the inventory with all checks green.


#### following delete
Notes & Guidance
Enable Azure Security Center on your Azure Arc connected machines.
In the Azure portal, navigate to the Security Center blade, select Security solutions, and then in the Add data sources section select Non-Azure servers.
On the Add new non-Azure servers blade, select the + Add Servers button referencing the Log Analytics workspace you created in the previous task.
Navigate to the Security Center | Pricing & settings blade and select the Log Analytics workspace.
On the Security Center | Getting Started blade and enable Azure Defender on the Log Analytics workspace.
Navigate to the Settings | Azure Defender plans blade and ensure that Azure Defender is enabled on 1 server.
Switch to the Settings | Data collection blade and select the Common option for collection of Windows security events.
Navigate to the arcch-vm1 blade, select Security, an verify that Azure Defender for Servers is On.
Success Criteria
Open Azure Security Center and view the Secure Score for your Azure arc connected machine.

Note: Alternatively, review the Security Center | Inventory blade and verify that it includes the Servers - Azure Arc entry representing the arcch-vm1 Hyper-V VM.
