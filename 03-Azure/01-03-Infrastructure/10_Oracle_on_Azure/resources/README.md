# 🚀 Oracle Database @ Azure (ODAA) - Deployment Scripts

## ⚙️ Install the Microhack Environment

The following resources needs to be created before the workshop start.

- 📦 Azure Resource Group
- ⚓ Azure Kubernetes Service (AKS)
- 🌐 Install Ingress Controller NGINX on AKS

> ⚠️ **IMPORTANT:** Make sure the CIDR of the created VNet is added to the Oracle NSG.

### 📋 Prerequisites

- 🔧 install Azure CLI
- ⚓ install kubectl
- 📦 install helm
- 🔍 install jq
- 💻 Scripts need to run on bash (Linux, MacOS, WSL2 on Windows)

### 🔐 Login to Azure and set the right subscription

~~~bash
az login --use-device-code
az account show
az account set -s sub-cptdx-01
~~~

### 🌍 Define some environment variables

~~~bash
rgName="odaa"
prefix="ODAA"
postfix=""

location="germanywestcentral"
~~~

### 🏗️ Create Azure Resources

> ℹ️ **NOTE:** Currently you will need to redo this steps for each Team environment. Make sure to change the postfix.

~~~bash
#create resource Group
az group create -n $rgName -l $location
### Create AKS
az deployment group create -n $prefix -g $rgName -f ./infra/bicep/main.bicep -p location=$location aksName=$prefix postfix=$postfix
# Verify the created resources, list all resource inside the resource group
az resource list -g $rgName -o table --query "[].{Name:name, Type:type}"
~~~

~~~text
Name                                 Type
-----------------------------------  ------------------------------------------
ODAA                                 Microsoft.Network/virtualNetworks
ODAA-default-nsg-germanywestcentral  Microsoft.Network/networkSecurityGroups
odaa                                 Microsoft.OperationalInsights/workspaces
ODAA                                 Microsoft.ContainerService/managedClusters
~~~

### ⚓ Connect to AKS

~~~bash
# login to aks
aksName=$prefix$postfix
az aks get-credentials -g $rgName -n $aksName --overwrite-existing
# list namespaces
kubectl get namespaces # should show default, kube-system, kube-public
~~~

~~~text
NAME                STATUS   AGE
default             Active   10m
gatekeeper-system   Active   9m37s
kube-node-lease     Active   10m
kube-public         Active   10m
kube-system         Active   10m
~~~

### 🌐 Install Ingress Controller

🌟 An ingress controller on Azure Kubernetes Service (AKS) manages external access to services running inside your cluster. It acts as a gateway, routing HTTP and HTTPS traffic from outside the cluster to the appropriate internal services based on rules you define. This enables features like SSL termination, load balancing, and path-based routing, making it easier to securely expose and manage multiple applications within AKS.

~~~bash
# Change directory to the scripts
# cd scripts/k8s_install/
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
kubectl create namespace ingress-nginx
helm install nginx-quick ingress-nginx/ingress-nginx -n ingress-nginx
# patch health probe:
kubectl patch service nginx-quick-ingress-nginx-controller -n ingress-nginx -p '{"metadata":{"annotations":{"service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path":"/healthz"}}}'
# verify if annotation is added
kubectl get service nginx-quick-ingress-nginx-controller -n ingress-nginx -o jsonpath='{.metadata.annotations}' | jq
kubectl get service --namespace ingress-nginx nginx-quick-ingress-nginx-controller --output wide
# get external IP of nginx controller
kubectl get service -n ingress-nginx -o jsonpath='{range .items[*]} {.status.loadBalancer.ingress[*].ip} {"\n"} {end}'
~~~

