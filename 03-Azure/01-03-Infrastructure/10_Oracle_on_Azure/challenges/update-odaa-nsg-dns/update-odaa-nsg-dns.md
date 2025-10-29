# 🔐 Challenge 3: Update Oracle ADB NSG and DNS Configuration

[Back to workspace README](../../README.md)

## 🌐 Network Security Group Configuration

You need to update the Oracle ADB Network Security Group (NSG) with the CIDR range of the VNet where your AKS cluster is deployed. This can be done via the Azure Portal.

## 📋 Steps

1. 🎯 Navigate to your Oracle ADB instance in the Azure Portal
2. 🔧 Locate the Network Security Group settings
3. ➕ Add the AKS VNet CIDR (e.g., `10.0.0.0/16`) to the allowed sources
4. 💾 Save the configuration
5. ✅ Test connectivity from AKS to verify the changes

See the [official Oracle documentation about Network Security Groups](https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/nsg-manage.htm) for more details.

## 🔍 DNS Configuration

Because we deployed our ODAA Autonomous Database in a different VNet than the one that contains your AKS cluster, you will need to extract the ODAA FQDN and IP Address from the Azure Portal and assign them to the Azure Private DNS Zones linked to the AKS VNet.

### Retrieve ODAA FQDN

First, we need to retrieve the Private DNS Zones created alongside the ODAA deployment.

~~~powershell
$subODAA="sub-team0" # replace with your ODAA subscription name
# switch to the corresponding subscription where ODAA is deployed
az account set -s $subODAA
$rgODAA="aks-team0" # replace with your ODAA resource group name
$zones = az network private-dns zone list -g $rgODAA --query "[].name" -o tsv
echo $zones
~~~

~~~text
gpdmotes.adb.eu-frankfurt-1.oraclecloud.com
gpdmotes.adb.eu-frankfurt-1.oraclecloudapps.com
~~~

### Create AKS DNS Records

There are multiple ways to create the required DNS records within the Azure Private DNS Zones that are linked to the AKS VNet. Here, we will use Azure Bicep via Azure CLI.

~~~powershell
# switch back to the subscription where AKS is deployed
$subAKS="sub-team0" # replace with your AKS subscription name
az account set -s $subAKS
$fqdnODAA = 'adb.eu-frankfurt-1.oraclecloud.com' # replace with your ODAA FQDN
$fqdnODAAApp = 'adb.eu-frankfurt-1.oraclecloudapps.com' # replace with your ODAA FQDN
$fqdnODAAIpv4 = '192.168.0.200' # replace with your ODAA private IP address
$rgAKS="aks-team0" # replace with your AKS resource group name
$vnetAKSName="aks-team0" # replace with your AKS resource group name
az deployment group create --resource-group $rgAKS --template-file resources/infra/bicep/dns.bicep -p vnetAKSName=$vnetAKSName fqdnODAA=$fqdnODAA fqdnODAAApp=$fqdnODAAApp fqdnODAAIpv4=$fqdnODAAIpv4

# iterate through all zones and list all A records
$zones = az network private-dns zone list --resource-group $rgAKS --query "[].name" -o tsv
foreach ($zone in $zones) {
    Write-Host "Listing A records for zone: $zone"
    az network private-dns record-set a list --zone-name $zone --resource-group $rgAKS --query "[].{Name:name, Records:aRecords[0].ipv4Address}" -o table
}
~~~

~~~text
Listing A records for zone: gpdmotes.adb.eu-frankfurt-1.oraclecloud.com
Name    Records
------  ----------
@       10.0.0.213
Listing A records for zone: gpdmotes.adb.eu-frankfurt-1.oraclecloudapps.com
Name    Records
------  ----------
@       10.0.0.213
~~~

[Back to workspace README](../../README.md)