# Walkthrough Challenge 1 - Onboarding your Kubernetes Cluster
Duration: 15-30 minutes

## Prerequisites
Please ensure that you successfully verified 
* the [general prerequisites](../../Readme.md#general-prerequisites) before starting this challenge.
* that you can see your two resource groups in the [Azure portal](https://portal.azure.com) depending on your LabUser number. I.e. if you are LabUser-37, you should see the resource groups "37-k8s-arc" and "37-k8s-onprem".
* that you can successfully connect to all [required Azure endpoints](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/network-requirements?tabs=azure-cloud)

💡*Hint*: There are several connectivity-check scripts available [here](../../lab/scripts/).

## Task 1 - Login to Azure
In your shell environment, login to Azure using the account you got assigned during the microhack.
```bash
az logout # only required if you are logged in with another user from a previous session

az login # browser popup opens with credential prompt. Provide the user credentials you got from your microhack coach
```
In case you are prompted to select a subscription, please do so. In the microhack environment you just can hit enter as you only have one subscription available.

Validate that you can see your two resource groups in the [Azure portal](https://portal.azure.com) depending on your LabUser number. I.e. if you are LabUser-37, you should see the resource groups "37-k8s-arc" and "37-k8s-onprem". 
Click on your onprem resource group's name (i.e. 37-k8s-onprem).
There should be 3 VMs in this resource group. Make sure that all VMs are in state 'running'. 
![img-start-vm](img/vm-start.png)

To connect to your k8s cluster, we first need to merge the cluster credentials into your local ~/.kube/config file. You can use the following bash script for this:
```bash
# Set admin username (use the admin_user value provided by your coach)
admin_user="<replace-with-admin_user-from-fixtures.tfvars>"

# Extract user number from Azure username (e.g., LabUser-37 -> 37)
azure_user=$(az account show --query user.name --output tsv)
user_number=$(echo $azure_user | sed -n 's/.*LabUser-\([0-9]\+\).*/\1/p')

# Get public ip of master node via Azure cli according to user-number
master_pip=$(az vm list-ip-addresses --resource-group "${user_number}-k8s-onprem" --name "${user_number}-k8s-master" --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)

# Create .kube directory if it doesn't exist
mkdir -p ~/.kube

# Copy the kubeconfig to standard location
scp $admin_user@$master_pip:~/.kube/config ~/.kube/config

# replace localhost address with the public ip of master node
sed -i "s/127.0.0.1/$master_pip/g" ~/.kube/config

# Now kubectl works directly on your local client - no need to ssh into the master node anymore
kubectl get nodes
```

## Task 2 - Connect K8s cluster using script

* In your shell go to the folder where you cloned the microhack repository
* Change to the sub-folder '03-Azure/01-03-Infrastructure/03_Hybrid_Azure_Arc_Kubernetes/walkthroughs/challenge-01'
* Execute the script to
    * register required resource providers in your subscription (this step may take several minutes if the resource providers have not been registered before):
        * Microsoft.Kubernetes
        * Microsoft.KubernetesConfiguration
        * Microsoft.ExtendedLocation
    * remove Azure Arc helm charts which might exist from previous connection attempts
    * install required Azure CLI extensions or update them to latest version:
        * connectedk8s
        * k8s-configuration
    * connecting the simulated onprem cluster to Azure Arc using the Azure CLI approach

💡 *Important*: Make sure that your kubectl works and is pointing to the k8s cluster you want to onboard before executing the script!

```bash
./az_connect_k8s.sh
```

Wait until the script terminates. Expected result should look comparable to this output: 

```bash
# adjust the prefix according to your microhack user number
export onprem_resource_group="${user_number}-k8s-onprem"
export arc_resource_group="${user_number}-k8s-arc"
export arc_cluster_name="${user_number}-k8s-arc-enabled"
export location="westeurope"
```

* Execute the script to
    * register required resource providers in your subscription (this step may take several minutes if the resource providers have not been registered before):
        * Microsoft.Kubernetes
        * Microsoft.KubernetesConfiguration
        * Microsoft.ExtendedLocation
    * remove Azure Arc helm charts which might exist from previous connection attempts
    * install required Azure CLI extensions or update them to latest version:
        * connectedk8s
        * k8s-configuration
    * connecting the simulated onprem cluster to Azure Arc using the Azure CLI approach

💡 *Important*: Make sure that your kubectl works and is pointing to the k8s cluster you want to onboard before executing the script!

```bash
# Login to Azure on the master node
az login

# Clone the repository (or copy the script content)
git clone https://github.com/microsoft/MicroHack.git
cd MicroHack/03-Azure/01-03-Infrastructure/03_Hybrid_Azure_Arc_Kubernetes/walkthroughs/challenge-01

# Make the script executable and run it
chmod +x az_connect_k8s.sh
./az_connect_k8s.sh 
```

Wait until the script terminates. Expected result should look comparable to this output:
```bash
Exporting environment variables
Registering Azure Arc providers
Namespace             RegistrationPolicy    RegistrationState
--------------------  --------------------  -------------------
Microsoft.Kubernetes  RegistrationRequired  Registered
Namespace                          RegistrationPolicy    RegistrationState
---------------------------------  --------------------  -------------------
Microsoft.KubernetesConfiguration  RegistrationRequired  Registered
Namespace                   RegistrationPolicy    RegistrationState
--------------------------  --------------------  -------------------
Microsoft.ExtendedLocation  RegistrationRequired  Registered
Getting AKS credentials (kubeconfig)
Merged "37-k8s-onprem" as current context in /home/simon/.kube/config
Clear cached helm Azure Arc Helm Charts
Checking if you have up-to-date Azure Arc AZ CLI 'connectedk8s' extension...
Latest version of 'connectedk8s' is already installed.

Use --debug for more information

Checking if you have up-to-date Azure Arc AZ CLI 'k8s-configuration' extension...
Latest version of 'k8s-configuration' is already installed.

Use --debug for more information

Connecting the cluster to Azure Arc
This operation might take a while...

Step: 2025-12-12T14-32-41Z: Validating custom access token
Step: 2025-12-12T14-32-41Z: Checking Provider Registrations
Step: 2025-12-12T14-32-42Z: Setting KubeConfig
Step: 2025-12-12T14-32-42Z: Escape Proxy Settings, if passed in
Step: 2025-12-12T14-32-42Z: Checking Connectivity to Cluster
Step: 2025-12-12T14-32-43Z: Do node validations
Step: 2025-12-12T14-32-43Z: Install Kubectl client if it does not exist
Step: 2025-12-12T14-32-43Z: Install Helm client if it does not exist
Step: 2025-12-12T14-32-43Z: Starting Pre-onboarding-check
Step: 2025-12-12T14-32-43Z: Creating folder for Cluster Diagnostic Checks Logs
Step: 2025-12-12T14-32-43Z: Get namespace of release: cluster-diagnostic-checks
Step: 2025-12-12T14-32-44Z: Determine Helmchart Export Path
Step: 2025-12-12T14-32-44Z: Pulling HelmChart: mcr.microsoft.com/azurearck8s/helmchart/stable/clusterdiagnosticchecks, Version: 1.31.2
Step: 2025-12-12T14-32-46Z: Chart path for Cluster Diagnostic Checks Job: /home/simon/.azure/PreOnboardingChecksCharts/clusterdiagnosticchecks
Step: 2025-12-12T14-32-46Z: Creating Cluster Diagnostic Checks job
Step: 2025-12-12T14-32-59Z: The required pre-checks for onboarding have succeeded.
Step: 2025-12-12T14-32-59Z: Checking if user can create ClusterRoleBindings
Step: 2025-12-12T14-32-59Z: Determining Cluster Distribution and Infrastructure
Connecting an Azure Kubernetes Service (AKS) cluster to Azure Arc is only required for running Arc enabled services like App Services and Data Services on the cluster. Other features like Azure Monitor and Azure Defender are natively available on AKS. Learn more at https://go.microsoft.com/fwlink/?linkid=2144200.
Step: 2025-12-12T14-32-59Z: Checking Connect RP is available in the Location passed in.
Step: 2025-12-12T14-32-59Z: Check if an earlier azure-arc release exists
Step: 2025-12-12T14-32-59Z: Get namespace of release: azure-arc
Step: 2025-12-12T14-33-01Z: Deleting Arc CRDs
Step: 2025-12-12T14-33-09Z: Check if ResourceGroup exists.  Try to create if it doesn't
Step: 2025-12-12T14-33-09Z: Generating Public-Private Key pair
Step: 2025-12-12T14-33-14Z: Generating ARM Request Payload
Step: 2025-12-12T14-33-14Z: Azure resource provisioning has begun.
Step: 2025-12-12T14-34-49Z: Checking Custom Location(Microsoft.ExtendedLocation) RP Registration state for this Subscription, and attempt to get the Custom Location Object ID (OID),if registered
Step: 2025-12-12T14-34-52Z: Azure resource provisioning has finished.
Step: 2025-12-12T14-34-53Z: Determine Helmchart Export Path
Step: 2025-12-12T14-34-53Z: Pulling HelmChart: mcr.microsoft.com/azurearck8s/batch1/stable/v2/azure-arc-k8sagents, Version: 1.31.3
Step: 2025-12-12T14-34-55Z: Starting to install Azure arc agents on the Kubernetes cluster.
{
  "aadProfile": {
    "adminGroupObjectIDs": null,
    "tenantId": null
  },
  [...]
    "arcAgentProfile": {
    "agentAutoUpgrade": "Enabled",
    "agentErrors": null,
    "agentState": null,
    "desiredAgentVersion": null,
    "systemComponents": null
  },
  "arcAgentryConfigurations": null,
  "azureHybridBenefit": "NotApplicable",
  "connectivityStatus": "Connecting",
  "distribution": "k3s",
  "distributionVersion": null,
  "gateway": null,
  [...]
  "location": "westeurope",
  "managedIdentityCertificateExpirationTime": null,
  "miscellaneousProperties": null,
  "name": "37-k8s-arc-enabled",
  "offering": null,
  "oidcIssuerProfile": null,
  "privateLinkScopeResourceId": null,
  "privateLinkState": "Disabled",
  "provisioningState": "Succeeded",
  "resourceGroup": "37-k8s-arc",
  "securityProfile": null,
  [...]
  "tags": {},
  "totalCoreCount": null,
  "totalNodeCount": null,
  "type": "microsoft.kubernetes/connectedclusters"
}
```
In the [Azure portal](https://portal.azure.com) type 'Azure Arc' into the search bar at the top of the page. In the results in section 'Services' click 'Azure Arc'.
In the Azure Arc page in the left navigation pane, open the 'infrastucture' section and click 'Kubernetes clusters'.
You should see your resource of type 'Kubernetes - Azure Arc'. (i.e. if you are LabUser-37 you should see a resource named '37-k8s-arc-enabled'). Click on the name of the resource matching your user number.

Notice the Arc Agent version in the overview page.

In the navigation pane in section 'Kubernetes resources' click on 'Namespaces'. You will see a prompt to provide an access token:

![access-token](img/access-token.png)

In order to get access to the k8s resources from the Azure portal assign your entra user a clusterRoleBinding with appropriate permissions:
```bash
# get the user principal from entra
azure_user=$(az ad signed-in-user show --query userPrincipalName -o tsv)

# create a clusterRoleBinding for the user
kubectl create clusterrolebinding demo-user-binding --clusterrole cluster-admin --user=$azure_user

```
Now, reload the resources page in the Azure portl. You should see at least the following namespaces:

![img-namespaces](img/namespaces.png)

You successfully completed challenge 1! 🚀🚀🚀

[Next challenge](../challenge-02/solution.md) - [Next Challenge's Solution](../../walkthroughs/challenge-02/solution.md)