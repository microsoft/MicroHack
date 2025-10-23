# 🧵 Challenge 8: (Optional) Use Azure Data Fabric with Oracle ADB

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

## 🛠️ Implementation Steps

> ℹ️ **NOTE**: This challenge section provides a framework for the integration. Please refer to Azure Data Fabric and Oracle ADB integration documentation for specific implementation steps and current best practices.

## 📚 Useful Resources

- 🌐 [Azure Data Fabric Documentation](https://docs.microsoft.com/en-us/azure/data-factory/)
- 🔶 [Oracle ADB Integration Guides](https://docs.oracle.com/en/cloud/paas/autonomous-database/)
- 🔗 [Hybrid Data Integration Patterns](https://docs.microsoft.com/en-us/azure/architecture/)

~~~powershell
# switch to the subscription where AKS is deployed
$subAKS="sub-1" # replace with your AKS subscription name
# Make sure your cli points to the AKS subscription
az account set --subscription $subAKS
# log into your AKS cluster if not already done
$rgAKS="odaa1" # replace with your AKS resource group name
$AKSClusterName="odaa1" # replace with your AKS cluster name
az aks get-credentials -g $rgAKS -n $AKSClusterName --overwrite-existing

helm show values oggfree/goldengate-bigdata >ggfabric.yaml
#getting public address of nginx ingress controller

# get the external IP of the ingress controller and strip spaces
$EXTIP = (kubectl get service -n ingress-nginx -o jsonpath='{range .items[*]}{.status.loadBalancer.ingress[*].ip} {end}') -replace '\s', ''

#putting the external address into the goldengate deployment
(Get-Content ggfabric.yaml) -replace 'xxx.xxx.xxx.xxx', $EXTIP.Trim() | Set-Content ggfabric.yaml
code ggfabric.yaml
~~~

Should look like this:

~~~yaml
    ### uses default SSL certificate of gateway/controller or specify a custom tls-secret here
    tlsSecretName: ggate-tls-secret
    vhostName: ggate.4.182.95.155.nip.io
  internal:
~~~

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
