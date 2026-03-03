# Walkthrough Challenge 5 - Configure Gitops for cluster management

[Back to challenge](../../challenges/challenge-05.md) - [Next Challenge's Solution](../challenge-06/solution.md)

### Prerequisites
* [helm](https://helm.sh/docs/intro/install/)
* Read and write permissions on the resource types
    * Microsoft.Kubernetes/connectedClusters 
    * Microsoft.ContainerService/managedClusters
    * Microsoft.KubernetesConfiguration/extensions
    * Microsoft.KubernetesConfiguration/fluxConfigurations
* Registration of the following Azure resource providers:
```bash
az provider register --namespace Microsoft.Kubernetes
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.KubernetesConfiguration
```
* Required cli extensions
```bash
az extension add -n k8s-configuration
az extension add -n k8s-extension
```
* Flux CLI installed (optional; not required for this challenge)
* Extension microsoft.flux installed on your kubernetes cluster
```bash
# Extract user number from Azure username (e.g., LabUser-37 -> 37)
azure_user=$(az account show --query user.name --output tsv)
user_number=$(echo $azure_user | sed -n 's/.*LabUser-\([0-9]\+\).*/\1/p')

export arc_resource_group="${user_number}-k8s-arc"
export arc_cluster_name="${user_number}-k8s-arc-enabled"

az k8s-extension create \
  --name fluxExtension \
  --cluster-name $arc_cluster_name \
  --resource-group $arc_resource_group \
  --cluster-type connectedClusters \
  --extension-type microsoft.flux
```
* **Your own fork of the MicroHack repository on GitHub**
  
  To push changes to the Flux configuration, you need your own fork of the MicroHack repository. Here's how to set it up:
  
  1. **Fork the repository** on GitHub:
     - Go to https://github.com/microsoft/MicroHack
     - Click the "Fork" button in the top-right corner
     - Complete the fork process
      - Ensure the fork is **public** for ease of use (no authentication needed for Flux)
  
  2. **Clone only the required folder** (sparse checkout) to keep the repository size small:
     ```bash
     # Create a directory for the repository
     mkdir microhack-gitops
     cd microhack-gitops
     
     # Initialize a git repository with sparse checkout
     git init
     git remote add origin https://github.com/<your-github-username>/MicroHack.git
     
     # Enable sparse checkout
     git config core.sparseCheckout true
     
     # Specify the folder to checkout (the namespaces folder for this challenge)
     echo "03-Azure/01-03-Infrastructure/03_Hybrid_Azure_Arc_Kubernetes/walkthroughs/challenge-05/namespaces" >> .git/info/sparse-checkout
     
     # Pull the content
     git pull origin main
     ```
  
     After this, you'll have only the `namespaces` folder with the configuration files you need to modify and push.

### Solution - Manage cluster configuration using GitOps
In order to manage a namespace via flux, you need a repository. In this microhack we're using a public github repository. If using a private repo make sure to add credentials so flux is able to access your repository. The following command creates a flux configuration which watches the namespaces folder within this repository. All namespace definitions found in this folder will be applied to the cluster.
```bash
repository="https://github.com/<your-github-username>/MicroHack" #Change to your own fork of the Microhack repository
path="/03-Azure/01-03-Infrastructure/03_Hybrid_Azure_Arc_Kubernetes/walkthroughs/challenge-05/namespaces"

az k8s-configuration flux create \
  --resource-group $arc_resource_group \
  --cluster-name $arc_cluster_name \
  --cluster-type connectedClusters \
  --name flux-config-namespace \
  --namespace flux-system \
  --scope cluster \
  --url $repository \
  --branch main \
  --interval 1m \
  --kustomization name=namespaces path=$path prune=true interval=1m
```

💡 **Note**: The `--interval 1m` parameter sets how often Flux checks your Git repository for changes, while the kustomization `interval=1m` controls how often the configuration is applied. Both are set to 1 minute for quick feedback during this challenge. In production this should be set in accordance to the --sync-timeout setting.

The first namespace from the existing YAML in the `namespaces` folder is created automatically after Flux picks up the configuration. This usually takes 1-2 minutes (the sync interval is set to 1 minute).

Now create an additional namespace for team1:
Copy itops.yaml and name it team1.yaml. Open it in your editor and change the labels.name and name values to "team1". Save the file and commit and push it. The flux configuration will pull the change on the next sync (typically within 1-2 minutes), and the new namespace will appear in your cluster.


### Resources
* [GitOps for Azure Kubernetes Service](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/gitops-aks/gitops-blueprint-aks)

You successfully completed challenge 5! 🚀🚀🚀
