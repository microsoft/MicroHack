# 🧵 Challenge 8: (Optional) Integration of Azure Data Fabric with Oracle ADB

[Back to workspace README](../../README.md)

## 🎯 Overview

🚀 This challenge focuses on integrating Oracle Autonomous Database (ADB) with Azure Data Fabric to create comprehensive data solutions that leverage both Oracle's database capabilities and Azure's data platform services.

## 📋 Key Integration Areas

1. **🔗 Data Connectivity**
   - Configure secure connections between Oracle ADB and Azure Data Fabric
   - Set up data source registrations

2. **📊 Data Pipeline Creation**
   - Build data pipelines to move data between Oracle ADB and Azure services
   - Implement real-time and batch data processing

3. **📈 Analytics and Reporting**
   - Create reports and dashboards using Azure Data Fabric tools
   - Leverage Power BI integration for visualization

4. **🔍 Data Governance**
   - Implement data lineage tracking
   - Set up data quality monitoring

## 🚀 Deploy GoldenGate for Azure Fabric on AKS

Log in to the AKS cluster where you want to deploy GoldenGate for Azure Fabric if not already done:

~~~powershell
# switch to the subscription where AKS is deployed
$subAKS="sub-mh1" # replace with your AKS subscription name
# Make sure your cli points to the AKS subscription
az account set --subscription $subAKS
# log in to your AKS cluster if not already done
$rgAKS="aks-user01" # replace with your AKS resource group name
$AKSClusterName="aks-user01" # replace with your AKS cluster name
az aks get-credentials -g $rgAKS -n $AKSClusterName --overwrite-existing
~~~

Once you have the external IP address, replace the placeholder in the gghack.yaml file.

~~~powershell
# get the external IP of the ingress controller and strip spaces
$EXTIP = (kubectl get service -n ingress-nginx -o jsonpath='{range .items[*]}{.status.loadBalancer.ingress[*].ip} {end}') -replace '\s', ''
# create a copy of the template file
cp resources/template/ggfabric.yaml .
# replace the placeholder with the actual external IP
(Get-Content ggfabric.yaml) -replace 'xxx-xxx-xxx-xxx', $EXTIP.Trim() | Set-Content ggfabric.yaml
code ggfabric.yaml
~~~

The value of vhostName should look like this:

~~~yaml
    ### uses default SSL certificate of gateway/controller or specify a custom tls-secret here
    tlsSecretName: ggate-tls-secret
    vhostName: ggfabric.xxx-xxx-xxx-xxx.nip.io
~~~

## 🚀 Install GoldenGate Pods

Install all components via Helm:

~~~powershell
helm install oggfabric oggfree/goldengate-bigdata --values ggfabric.yaml -n microhacks
~~~

~~~text
NAME: oggfabric
LAST DEPLOYED: Wed Oct 22 18:31:24 2025
NAMESPACE: microhacks
STATUS: deployed
REVISION: 1
TEST SUITE: None
~~~

~~~powershell
# See deployment.apps/oggfabric-goldengate-bigdata
kubectl describe deployment oggfabric-goldengate-bigdata -n microhacks
# get our pod 
$podOGGfabric = kubectl get pods -n microhacks | Select-String 'oggfabric-goldengate-bigdata' | ForEach-Object { ($_ -split '\s+')[0] }
# get details
kubectl describe pod $podOGGfabric -n microhacks
# Check used image:
kubectl get deployment oggfabric-goldengate-bigdata -n microhacks -o jsonpath='{.spec.template.spec.containers[0].image}'
# check used services
kubectl get service --namespace ingress-nginx nginx-quick-ingress-nginx-controller --output wide
# get external IP of nginx controller, you maybe need to wait a few minutes until the IP is assigned
kubectl get service -n microhacks -o jsonpath='{.items[*].status.loadBalancer.ingress[*].ip}'
~~~

You can now access the GoldenGate Microservices UI at: `https://ggfabric.<EXTERNAL_IP>.nip.io` (e.g. `https://ggfabric.xxx.xxx.xxx.xxx.nip.io`)


## 📚 Useful Resources

- 🌐 [Azure Data Fabric Documentation](https://docs.microsoft.com/en-us/azure/data-factory/)
- 🔶 [Oracle ADB Integration Guides](https://docs.oracle.com/en/cloud/paas/autonomous-database/)
- 🔗 [Hybrid Data Integration Patterns](https://docs.microsoft.com/en-us/azure/architecture/)

## 💡 Tips and Tricks

### 🔁 Redeploy if things go wrong

~~~powershell
# login to aks
az aks get-credentials -g $rgAKS -n $AKSClusterName --overwrite-existing
# Uninstall the Helm release
helm uninstall oggfabric -n microhacks
~~~

### 🔐 Use a private Oracle Container Registry image

~~~powershell
# delete secret if already exist
kubectl delete secret container-registry-secret -n microhacks

# Prompt for the password that will be used for all three components
$password = Read-Host -Prompt "Enter the shared password"

kubectl create secret docker-registry container-registry-secret -n microhacks  --docker-username=test@gmail.com --docker-password=$password --docker-server=container-registry.oracle.com

[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(
    (kubectl get secret container-registry-secret -n microhacks -o jsonpath="{.data.\.dockerconfigjson}")
))
~~~

[Back to workspace README](../../README.md)