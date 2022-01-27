# Exercise 3: FSLogix Profile Solution

[Previous Challenge](./00-Pre-Reqs.md) - **[Home](../readme.md)** - **[Next Challenge](02-multi-session-Hostpools.md)**

## Introduction
In this challenge, you'll learn how to create an Azure Files share to store FSLogix profiles that can be accessed by hybrid user identities authenticated with Azure Active Directory (AD). Azure AD users can now access an Azure file share using Kerberos authentication. This configuration uses Azure AD to issue the necessary Kerberos tickets to access the file share with the industry-standard SMB protocol. Your end-users can access Azure file shares over the internet without requiring a line-of-sight to domain controllers from Hybrid Azure AD-joined and Azure AD-joined VMs.

In this challenge, you'll learn how to:

Configure an Azure storage account for authentication using Azure AD.
Configure the permissions on an Azure Files share.
Configure your session hosts to store FSLogix user profiles on Azure Files.

## Challenge 
- Create a storage account in your subscription for Azure file shares 
- Configure Azure AD authentication on your Azure Storage account
- Configure the Azure AD service principal and application (to enable Azure AD authentication on a storage account, you need to create an Azure AD application to represent the
  storage account in Azure AD).
- Set the API permissions on the newly created application
- Configure your Azure Files share
- Assign share-level permissions to grant your users access to the file share before they can use it
- Assign directory level access permissions to prevent users from accessing the user profile of other users
- Configure the session hosts to access Azure file shares from an Azure AD-joined VM for FSLogix profiles
- Configure FSLogix on the session host to to create the Enabled and VHDLocations registry values. Set the value of VHDLocations to your previously created fileshare name



## Success Criteria
- Test your deployment
- Once you've installed and configured FSLogix, you can test your deployment by signing in with a user account that's been assigned to an application group on the host pool. 
- The user account you sign in with must have permission to use the file share.
- If the user has signed in before, they'll have an existing local profile that the service will use during this session. To avoid creating a local profile, either create a new
  user account to use for tests or use the configuration methods described in Tutorial: [Configure profile container to redirect user profiles to enable the DeleteLocalProfileWhenVHDShouldApply setting](https://docs.microsoft.com/en-us/fslogix/configure-profile-container-tutorial/).
 - Finally, test the profile to make sure that it works


### Disclaimer
Storing FSLogix profiles on Azure Files for Azure Active Directory (AD)-joined VMs is currently in public preview. This preview version is provided without a service level agreement, and is not recommended for production workloads. Certain features might not be supported or might have constrained capabilities. 
For more information, see [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms)


### Learning Resources
[Create a profile container with Azure Files and Azure Active Directory (preview)](https://docs.microsoft.com/en-us/azure/virtual-desktop/create-profile-container-azure-ad)
[Create a storage account for Azure File Shares](https://docs.microsoft.com/en-us/azure/storage/files/storage-how-to-create-file-share?tabs=azure-portal#create-a-storage-account)
[Configure FSLogix for the Enterprise](https://docs.microsoft.com/en-us/azure/architecture/example-scenario/wvd/windows-virtual-desktop-fslogix)

