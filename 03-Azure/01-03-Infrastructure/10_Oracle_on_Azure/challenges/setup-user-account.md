# Set Up Your User Account

Before we start with the Microhack you should have 3 passwords:
1. You User with the initial password for the registration, which you have to change during the registration
   
2. The password you need to use for admin user of the ADB deployment - <font color=red>Don't use different passwords</font>
3. The password you need to use for the AKS cluster deployment  - <font color=red>Don't use different passwords</font>


Open a private browser session or create an own browser profile to sign in with the credentials you received, and register multi-factor authentication. In a first check you have to verify if the two resource groups for the hackathon are created.
<br>
The goal is to ensure your Azure account is ready for administrative work in the remaining challenges.

#### Actions
* Enable the multi factor authentication (MFA)
* Login into the Azure portal with the assigned User
* Verify if the ODAA and AKS resource group including resources are available
* Verfity the users roles
  

#### Sucess criteria
* Download the Microsoft authenticator app on your mobile phone
* Enable MFA for a successful Login
* Check if the resource groups for the aks and ODAA are available and contains the resources. 
* Check if the assigned user have the required roles in both resource groups.

#### Learning Resources
* [Sign in to the Azure portal](https://learn.microsoft.com/azure/azure-portal/azure-portal-sign-in), 
* [Set up Microsoft Entra multi-factor authentication](https://learn.microsoft.com/azure/active-directory/authentication/howto-mfa-userdevicesettings)
* [Groups and roles in Azure](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/oaagroupsroles.htm)