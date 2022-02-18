## Exercise 6: Configure MFA

Duration:


[Previous Challenge Solution](./xxxx.md) - **[Home](../readme.md)**

In this challenge, you will configure enable Azure multifactor authentication for Azure Virtual Desktop and configure MFA.

**Additional Resources**

  |              |            |  
|----------|:-------------:|
| Description | Links |
| Enable MFA | https://docs.microsoft.com/en-us/azure/active-directory/authentication/howto-mfa-userstates#view-the-status-for-a-user |
| Create a Conditional Access policy | https://docs.microsoft.com/en-us/azure/virtual-desktop/set-up-mfa#create-a-conditional-access-policy|
  |              |            | 

### Task1:
Enable MFA for your user accounts and assign an Azure Active Directory P1 or P2 License. 

### Task2: 
 In this task we will create an Conditional Access policy.

- You need to be signed in as a global administrator, security administrator, or conditional access administrator
- In Azure Active Directory create a group and add your AVD users to that group
- Now browse to AAD > Security and then to conditional access within the Azure Portal and create a new policy
- Assign the policy to the group you created before and click *Done* 
- 
