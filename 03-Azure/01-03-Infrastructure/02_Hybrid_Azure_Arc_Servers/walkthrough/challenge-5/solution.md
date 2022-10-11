## Action 1: Create an Azure Policy Guest Configuration for your Azure Arc VMs

### Setup a Policy that checks if the user "FrodoBaggins" is part of the local administrators group


1. Please navigate to Azure Policy.

2. Navigate to *Assignments* in the left navigation pane and select *Assign policy* in the top menu.

![PolicyAssignment.png](./img/PolicyAssignment.png)

3. In this section you can now configure the assignment with the following settings and create the assignment:

- Scope: Please select the resource group called *AzStackHCI-MicroHack-Azure*
- Policy Definition: Please search for *administrators group* and select *Audit Windows machines missing any of the specified members in the Administrators group*.
- Parameters: Please ensure to set *Include Arc connected servers* to *true and *Members to include* to *FrodoBaggins*.

![PolicyAssignmentBasics.png](./img/PolicyAssignmentBasics.png)

![PolicyAssignmentParameters.png](./img/PolicyAssignmentParameters.png)

❗Hint: This example does not include remediation. If you want to learn more on how to use guest configuration to remediate the state of your servers please refer to [Remediation options for guest configuration](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/guest-configuration-policy-effects). 

4. On Non-Compliance Message you can create a custom message that may contain additional information like link to internal documentation or just an explaination why this policy is set.

![PolicyAssignmentMessage.png](./img/PolicyAssignmentMessage.png)

5. Review the policy assignment and select *Create*.

![PolicyAssignmentReview.png](./img/PolicyAssignmentReview.png)

6. After a few minutes you will be able to see the compliance state of your Windows-based servers.