# Exercise 2: Create a custom golden image

Duration: 45 min

[Previous Challenge Solution](./01-Personal-Hostpools-solution.md) - **[Home](../Readme.md)** - [Next Challenge Solution](./03-multi-session-Hostpools-solution.md)

In this challenge, you will learn about creating a customized Azure Virtual Desktop image using the Azure VM Image Builder and then offering that image through the Azure Compute Gallery. There are several ways to create a custom golden image. This can be done manually by first creating an Azure VM and then generalizing and capturing it. Alternatively, PowerShell commands, ARM templates, or the Custom Image Template feature accessible from the Azure Portal GUI can be used. This feature guides you through the prerequisites and process of using Azure Image Builder. You should use the Custom Image Template in this challenge. 


**Additional Resources**
|              |            |  
|----------|:-------------|
| Description | Links |
| Azure VM Image Builder overview | https://learn.microsoft.com/en-us/azure/virtual-machines/image-builder-overview?tabs=azure-powershell |
| Create an Azure Virtual Desktop image by using VM Image Builder and PowerShell |  https://learn.microsoft.com/en-us/azure/virtual-machines/windows/image-builder-virtual-desktop | 
| Custom image templates in Azure Virtual Desktop (preview) | https://learn.microsoft.com/en-us/azure/virtual-desktop/custom-image-templates |

# Task 1 - Register the Azure VM Image Builder Features and create a Custom Image 


Azure Image Builder is generally available. In this task, you will learn how to register this feature.

1. Logon to **Windows Client 01** using the provided credentials under **Resources** in the right pane.

2. Open a **PowerShell Core** terminal on your **Windows Client 01** as administrator.

>[!important]**PowerShell Core** is installed, configured, and executed **separately** from Windows PowerShell. It does not replace your default PowerShell instance. To run PowerShell Core open your start menu and type **pwsh**.

>[!hint]The PowerShell modules **Az.ImageBuilder** and **Az.ManagedServiceIdentity** are required for building an Azure Image. These modules are pre-installed on your **Windows Client 01**. 

3. Update *Azure Image Builder* and *Managed Service Identity* PowerShell modules to the latest version, if needed. 

```PowerShellCore-wrap
Update-Module Az.ImageBuilder
Update-Module Az.ManagedServiceIdentity
```
4. Connect to the Azure Virtual Desktop service with following command.

```PowerShellCore-wrap
# Connect to Azure with a browser sign in token
Connect-AzAccount
```

The browser "Sign in to your account" page should open. Login with your global admin account.

![Powershell01.png](../Images/Powershell01.png)

You can return to the application. Feel free to close the browser tab. You are signed directly into the subscription that is default for your admin credentials in the Powershell session.
Sign in using your Azure admin credentials.

```Output-nocopy
Account                           SubscriptionName         TenantId                             Environment
-------                           ----------------         --------                             -----------
admin@M365xxxxxxx.onmicrosoft.com Azure Pass - Sponsorship xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx AzureCloud
```

>[!alert] You may get an output as showcased below (i.e. an empty SubscriptionName). If the SubscriptionName is filled with your **Azure Pass** subscription name, skip this alert box. The missing name implies that the authentication information for cmdlets is not set correctly in your current session: 
>
>```Output-nocopy
>Account                           SubscriptionName         TenantId                             Environment
>-------                           ----------------         --------                             -----------
>admin@M365xxxxxxx.onmicrosoft.com                          xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx AzureCloud
>```
>To select your subscription run the following commands:
>
>```Powershell
>$AzSub = Get-AzSubscription
>Set-AzContext -SubscriptionId $AzSub.SubscriptionId
>```
>Your output should look like this:
>
>```Output-nocopy
>Account                           SubscriptionName         TenantId                             Environment
>-------                           ----------------         --------                             -----------
>admin@M365xxxxxxx.onmicrosoft.com Azure Pass - Sponsorship xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx AzureCloud
>```

5. To use Azure Image Builder, you have to register for the providers and to ensure that **RegistrationState** will be set to **Registered**.

```PowerShellCore-wrap
Register-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages
Register-AzResourceProvider -ProviderNamespace Microsoft.Storage
Register-AzResourceProvider -ProviderNamespace Microsoft.Compute
Register-AzResourceProvider -ProviderNamespace Microsoft.KeyVault
Register-AzResourceProvider -ProviderNamespace Microsoft.ManagedIdentity
```
Run the following commands from time to time to verify that the state of the provider registration process changed to **Registered** for all providers.

```PowerShellCore-wrap
Get-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages | Where RegistrationState -ne Registered
Get-AzResourceProvider -ProviderNamespace Microsoft.Storage | Where RegistrationState -ne Registered 
Get-AzResourceProvider -ProviderNamespace Microsoft.Compute | Where RegistrationState -ne Registered
Get-AzResourceProvider -ProviderNamespace Microsoft.KeyVault | Where RegistrationState -ne Registered
Get-AzResourceProvider -ProviderNamespace Microsoft.ManagedIdentity | Where RegistrationState -ne Registered
```
>[!alert]**Important**: Wait until **RegistrationState** is set to **Registered**. In the meantime, feel free to grab a cup of coffee or visit [Azure Image Builder overview](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-overview) docs page to familiarize yourself with the intricate features of the Azure VM Image Builder service.

**Important**: Do not proceed with the next step, unless the output does not yield any results! 

6. Next, you will set several variables because you will be using several pieces of information repeatedly and create a resource group:

>[!alert] The Azure Image Builder is available and supported in the following regions:
>- East US
>- East US 2
>- West Central US
>- West US
>- West US 2
>- West US 3
>- South Central US
>- North Europe
>- West Europe
>- South East Asia
>- Australia Southeast
>- Australia East
>- UK South
>- UK West
>- Brazil South
>- Canada Central
>- Central India
>- Central US
>- France Central
>- Germany West Central
>- Japan East
>- North Central US
>- Norway East
>- Switzerland North
>- Jio India West
>- UAE North
>- East Asia
>- Korea Central
>- South Africa North
>- Qatar Central
>- USGov Arizona (public preview)
>- USGov Virginia (public preview)
>
>The location variable below must reflect one of these regions. If you are NOT deploying your AVD host pools in one of these regions you will need to use the **Azure Compute Gallery** to distribute the resulting managed image to your location to be able to use it for host pool deployment. If you are deploying your AVD host pools in one of these regions you will need to use the **Azure Compute Gallery** as well, but not for the distribution of the images to other locations. In that case **SIG** is used as your company controlled gallery. Here you will find the latest information about the region: [Azure Image Builder Regions](https://docs.microsoft.com/en-us/azure/virtual-machines/image-builder-overview#regions)

```PowerShell-linenums-notab
# get existing context
$currentAzContext = Get-AzContext

# destination image resource group
$imageResourceGroup="rg-avd-azimg"

# location
$location="EastUS"

# get your current subscription
$subscriptionID=$currentAzContext.Subscription.Id

# create resource group
New-AzResourceGroup -Name $imageResourceGroup -Location $location
```

```Output-nocopy
ResourceGroupName : rg-avd-azimg
Location          : eastus
ProvisioningState : Succeeded
Tags              :
ResourceId        : /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx/resourceGroups/rg-avd-azimg
```

7. Create a user identity and role for AIB.

>[!note]By default, Image Builder supports using scripts, or copying files from multiple locations, such as GitHub and Azure storage. To use these, they must be publicly accessible. Beginning of June 2020 you need to use an Azure User-Assigned Managed Identity, defined by you, to allow Image Builder access Azure Storage, as long as the identity has been granted a minimum of **Storage Blob Data Reader*** on the Azure storage account. This means you do not need to make the storage blobs externally accessible, or setup SAS Tokens.

```PowerShell-linenums-notab
# setup role def names, these need to be unique
$timeInt=(Get-Date -UFormat "%s").Split(".")[0]
$imageRoleDefName="Azure Image Builder Image Def"+$timeInt
$identityName="aibIdentity"+$timeInt

# create identity
New-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName -Location $location 

$identityNameResourceId=$(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).Id
$identityNamePrincipalId=$(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).PrincipalId
```

You should get similar result back:

```Output-nocopy
Location Name                  ResourceGroupName
-------- ----                  -----------------
eastus   aibIdentity1649143235 rg-avd-azimg
```

8. Assign permissions for the recently created managed identity to distribute images.

```PowerShell-linenums-notab
# create temp folder 
$FolderPath = "C:\temp\"
New-Item -Path $FolderPath -ItemType Directory -Force

$aibRoleImageCreationUrl="https://raw.githubusercontent.com/PeterR-msft/M365AVDWS/master/Azure%20Image%20Builder/aibRoleImageCreation.json"
$aibRoleImageCreationPath = $FolderPath + "aibRoleImageCreation.json"

# download config
Invoke-WebRequest -Uri $aibRoleImageCreationUrl -OutFile $aibRoleImageCreationPath -UseBasicParsing

((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<subscriptionID>',$subscriptionID) | Set-Content -Path $aibRoleImageCreationPath
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<rgName>', $imageResourceGroup) | Set-Content -Path $aibRoleImageCreationPath
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace 'Azure Image Builder Service Image Creation Role', $imageRoleDefName) | Set-Content -Path $aibRoleImageCreationPath

# create role definition
New-AzRoleDefinition -InputFile $aibRoleImageCreationPath

# wait for role creation
Start-Sleep 10

# grant role definition to image builder service principal
New-AzRoleAssignment -ObjectId $identityNamePrincipalId -RoleDefinitionName $imageRoleDefName -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"
```

>[!important]**Note:** Should you experience the following error *New-AzRoleDefinition: Role definition limit exceeded. No more role definitions can be created.*, then follow the steps in this document:
`https://docs.microsoft.com/en-us/azure/role-based-access-control/troubleshooting`

```Output-nocopy
    Directory: C:\

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d----            6/8/2020  9:33 AM                temp

Name             : Azure Image Builder Image Def1591779867
Id               : 29b591b5-6dd8-482c-9f4f-3ec4caed73e9
IsCustom         : True
Description      : Image Builder access to create resources for the image build, you should delete or split out as
                   appropriate
Actions          : {Microsoft.Compute/galleries/read, Microsoft.Compute/galleries/images/read,
                   Microsoft.Compute/galleries/images/versions/read,
                   Microsoft.Compute/galleries/images/versions/write???}
NotActions       : {}
DataActions      : {}
NotDataActions   : {}
AssignableScopes : {/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx/resourceGroups/rg-avd-azimg}


RoleAssignmentId   : /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx/resourceGroups/rg-avd-azimg/providers/Microsof
                     t.Authorization/roleAssignments/ccba0b29-4420-4340-a646-8d8a195dd749
Scope              : /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx/resourceGroups/rg-avd-azimg
DisplayName        : aibIdentity1591779867
SignInName         :
RoleDefinitionName : Azure Image Builder Image Def1591779867
RoleDefinitionId   : 29b591b5-6dd8-482c-9f4f-3ec4caed73e9
ObjectId           : ef57ff40-337e-49cb-8058-8d082b58e357
ObjectType         : ServicePrincipal
CanDelegate        : False
```

9. Create a Azure Compute Gallery using **New-AzGallery**. An image gallery is the primary resource used for enabling image sharing. Allowed characters for Gallery name are uppercase or lowercase letters, digits, dots, and periods. The gallery name cannot contain dashes. Gallery names must be unique within your subscription.

```PowerShell-linenums-notab
# Azure Compute Gallery properties
$sigGalleryName= "AVDSIG"
$imageDefName ="AVD-Img-Definitions"

# create SIG
New-AzGallery -GalleryName $sigGalleryName -ResourceGroupName $imageResourceGroup -Location $location

# create gallery definition
$GalleryParams = @{
  GalleryName = $sigGalleryName
  ResourceGroupName = $imageResourceGroup
  Location = $location
  Name = $imageDefName
  OsState = 'generalized'
  OsType = 'Windows'
  Publisher = 'Contoso'
  Offer = 'Windows'
  Sku = 'Win11WVD'
  HyperVGeneration = 'V2'
}
New-AzGalleryImageDefinition @GalleryParams
```

>[!hint]There is no extra charge for using the Azure Compute Gallery service. You will be charged for the following resources:
>
>- Storage costs of storing the Shared Image versions. Cost depends on the number of replicas of the image version and the number of regions the version is replicated to. For example, if you have 2 images and both are replicated to 3 regions, then you will be charged for 6 managed disks based on their size. For more information, see [Managed Disks pricing](https://azure.microsoft.com/en-us/pricing/details/managed-disks/).
>- Network egress charges for replication of the first image version from the source region to the replicated regions. Subsequent replicas are handled within the region, so there are no additional charges.

```Output-nocopy
ResourceGroupName : rg-avd-azimg
  UniqueName      : xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx-AVDSIG
ProvisioningState : Succeeded
Id                : /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx/resourceGroups/rg-avd-azimg/providers/Microsoft.Compute/galleries/AVDSIG
Name              : AVDSIG
Type              : Microsoft.Compute/galleries
Location          : eastus
Tags              : {}

ResourceGroupName : rg-avd-azimg
OsType            : Windows
OsState           : Generalized
HyperVGeneration  : V2
Identifier        :
  Publisher       : Contoso
  Offer           : Windows
  Sku             : Win11WVD
ProvisioningState : Succeeded
Id                : /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx/resourceGroups/rg-avd-azimg/providers/Microsoft
.Compute/galleries/AVDSIG/images/AVD-Img-Definitions
Name              : AVD-Img-Definitions
Type              : Microsoft.Compute/galleries/images
Location          : eastus
Tags              : {}
```

10. To allow Azure VM Image Builder to distribute images to either the managed images or to a Azure Compute Gallery, you will need to provide **Contributor** permissions for the service "**Azure Virtual Machine Image Builder**" (ApplicationId: **cf32a0cc-373c-47c9-9156-0db11f6a6dfc**) on the resource group.

```PowerShellCore-wrap
# assign permissions for the resource group, so that AIB can distribute the image to it
New-AzRoleAssignment -ApplicationId cf32a0cc-373c-47c9-9156-0db11f6a6dfc -Scope /subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup -RoleDefinitionName Contributor
```

```Output-nocopy-nocolor
RoleAssignmentId   : /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/vwd-master-image/providers/Microsoft.Authorization/ro
                     leAssignments/cefb7489-5c95-4644-b623-7ec19fad78ad
Scope              : /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/vwd-master-image
DisplayName        : Azure Virtual Machine Image Builder
SignInName         : 
RoleDefinitionName : Contributor
RoleDefinitionId   : cefb7489-5c95-4644-b623-7ec19fad78ad
ObjectId           : ef511139-6170-438e-a6e1-763dc31bdf74
ObjectType         : ServicePrincipal
CanDelegate        : False
```

>[!hint]If the service account is not found, that may mean that the subscription where you are adding the role assignment has not yet completed the resource provider registration.

11. Open the [Azure Virtual Desktop site](https://azavd.cmd.ms/).

12. Next, select **Custom image templates** in the menu on the left side of the screen.

![02-CustomImageTemplate-0.png](../Images/02-CustomImageTemplate-0.png)

13. Select **Add custom image template**.

![02-CustomImageTemplate-1.png](../Images/02-CustomImageTemplate-1.png)

14. In the **Basics** tab, enter the following information.

| Field | Value | Notes
|:---------|:---------|:---------|
| Template name | `avd-win11-img-template` |
| Import from existing template | No  | 
| Subscription | Azure Pass - Sponsorship |
| Resource Group | rg-avd-azimg | You created this RG in an earlier task.
| Location | (US) East US |
| Managed identity | aibIdentityXXXXXXXX | You created this managed identity in an earlier task.

![02-CustomImageTemplate-2.png](../Images/02-CustomImageTemplate-2.png)

Select **Next**.

14. Then select the following **Source image information**:

| Field | Value | Notes
|:---------|:---------|:---------|
| Source type |Platform image (marketplace) |
| Select image | Windows 11 Enterprise multi-session + Microsoft 365 Apps, Version 22H2  | 

![02-CustomImageTemplate-3.png](../Images/02-CustomImageTemplate-3.png)

Select **Next**.

15. In the distibution targets tag, select **Azure Compute Gallery** and enter the following information:

>[!alert]If you want to deploy your session hosts to one of the regions currently not supported by Azure Image Builder (or if you just want to have your image made available in other regions) we recommend to use the Azure Compute Gallery to distribute your managed image to other locations. The primary purpose of using the Azure Compute Gallery is to replicate your master image to other Azure regions automatically. You can accomplish that by appending a second region to the Replication regions list. 

>If you are building your master image in the same region as your CONTOSODC AND if the Azure Image Builder service is available there ([Azure Image Builder Regions](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-overview?toc=/azure/virtual-machines/windows/toc.json&bc=/azure/virtual-machines/windows/breadcrumb/toc.json#regions)), then you may leave the Replication region parameter in the table below. Remember that the managed image has to be available in the Azure region you are planning to create session hosts. Additionally, session host VM require a direct line of sight to your DC.

| Field | Value | Notes
|:---------|:---------|:---------|
| Gallery name | AVDSIG |
| Gallery image definition | AVD-Img-Definitions  | 
| Gallery Image version | `0.0.1` | It's optional.
| Run output name | `winclientR01` | This value can be anything, it is just the name for the temporary resource group
| Replication regions | East US | 
| Exclude from latest | No | It's the first version.
| Storage account type | Standard_LRS |

![02-CustomImageTemplate-4.png](../Images/02-CustomImageTemplate-4.png)

Select **Next**.

16. Next, you can change some build properties, but you can skip that for now and click **Next**.

17. On the Customizations tab, click **Add built-in Script**.

![02-CustomImageTemplate-5.png](../Images/02-CustomImageTemplate-5.png)

18. Next, you can add some built-in scripts to customize your Azure image and select the following scripts and customizations here.

**Operating system specific scripts:**

| Field | Value | Notes
|:---------|:---------|:---------|
| Time zone redirection | Enabled |

![02-CustomImageTemplate-6.png](../Images/02-CustomImageTemplate-6.png)


**Application scripts:**

| Field | Value | Notes
|:---------|:---------|:---------|
| Remove Appx packages | Enabled |
| Valid packages | Microsoft.GamingApp; Microsoft.XboxApp; Microsoft.Xbox.TCUI; Microsoft.XboxGameOverlay; Microsoft.XboxGamingOverlay; Microsoft.XboxIdentityProvider; Microsoft.XboxSpeechToTextOverlay; Microsoft.ZuneMusic; Microsoft.ZuneVideo   |

![02-CustomImageTemplate-7.png](../Images/02-CustomImageTemplate-7.png)


Select **Save**.

19. Then select **Add Custom Script** to add your automation script, for example, to install Visual Studio Code in your custom image.

![02-CustomImageTemplate-8.png](../Images/02-CustomImageTemplate-8.png)


20. Enter the following information:

| Field | Value | Notes
|:---------|:---------|:---------|
| Script name | `winclientR01` |
| URI | `https://raw.githubusercontent.com/dweppeler-msft/AVD/main/AIB%20Template/InstallVSCode.ps1` |

![02-CustomImageTemplate-9.png](../Images/02-CustomImageTemplate-9.png)

Select **Save**.

21.  Click **Next** to go to the Tags tab, which can be skipped, so **Next** again to the last tab **Check and Create**.

![02-CustomImageTemplate-10.png](../Images/02-CustomImageTemplate-10.png)


22. The last step is to click **Create** to create this custom image template, but this does not start the creation process yet.

![02-CustomImageTemplate-11.png](../Images/02-CustomImageTemplate-11.png)


23. When the customer image template is successfully created, you can start the image creation process by clicking **Start build**.

![02-CustomImageTemplate-12.png](../Images/02-CustomImageTemplate-12.png)


In the background, Azure Image Builder will create a staging resource group in your subscription. This resource group is used for the image build. It's in the format: **IT_%DestinationResourceGroup%_%TemplateName%**.

>[!alert]Do not delete the staging resource group directly. Delete the image template artifact, this will cause the staging resource group to be deleted. Task 3 will introduce the concept of cleanup.

In the meantime, open with a browser the Azure portal and navigate to the **All resources** view. You should see - depending on the build task's progress - the staging resource group, a storage account and the new VM image.

```PowerShell-notab
https://portal.azure.com/
```
![02-CustomImageTemplate-13.png](../Images/02-CustomImageTemplate-13.png)

>[!important]The distribution process may take some time (approx. 60-90 minutes) to complete. You will not be able to complete exercise 2 before your custom image is available in your replication region. 

>[!knowledge]The time it takes to replicate to different regions depends on the amount of data being copied and the number of regions the version is replicated to. This can take a few hours in some cases. While the replication is happening, you can view the status of replication per region. Once the image replication is complete in a region, you can then deploy a VM or scale-set using that image version in the region.

**Task 1 has been completed** 