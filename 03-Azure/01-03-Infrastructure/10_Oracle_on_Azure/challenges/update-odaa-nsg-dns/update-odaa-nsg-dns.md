# 🔐 Challenge 2: Update Oracle ADB NSG with AKS VNet CIDR

[Back to workspace README](../../README.md)

## 🌐 Network Security Group Configuration

You need to update the Oracle ADB NSG with the CIDR of the VNet where your AKS cluster is deployed. This can be done via the Azure Portal.

TBD: Add the AKS VNet CIDR (e.g., `10.10.0.0/16`) to the allowed sources in the NSG.

## 🔍 DNS Configuration

### Retrieve ODAA FQDN

In case you did deploy your ODAA in a different Subscription as the one which does contain your AKS cluster, you will need to extract the ODAA FQDN and IP Address from the Azure Portal.

Afterwards you need to run the following bicep command to update your DNS configuration:

~~~bash
$subODAA="ODAA" # replace with your ODAA subscription name
# switch to the corresponding subscription where ODAA is deployed
az account set -s $subODAA
$rgODAA="odaa2" # replace with your AKS resource group name
$zones = az network private-dns zone list -g $rgODAA --query "[].name" -o tsv
echo $zones
~~~

~~~text
gpdmotes.adb.eu-frankfurt-1.oraclecloud.com
gpdmotes.adb.eu-frankfurt-1.oraclecloudapps.com
~~~

### Create AKS DNS

Also consider aligning your DNS configuration based on the Oracle documentation:
📚 [Network DNS Configuration Guide](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/network-dns.htm)

~~~powershell
# switch back to the subscription where AKS is deployed
$subAKS="sub-1" # replace with your AKS subscription name
az account set -s $subAKS
$fqdnODAA = 'gpdmotes.adb.eu-frankfurt-1.oraclecloud.com'# replace with your ODAA FQDN
$fqdnODAAApp = 'gpdmotes.adb.eu-frankfurt-1.oraclecloudapps.com' # replace with your ODAA FQDN
$fqdnODAAIpv4  = '10.0.0.213'
$rgAKS="odaa1" # replace with your AKS resource group name
$vnetAKSName="odaa1" # replace with your AKS resource group name
az deployment group create --resource-group $rgAKS --template-file resources/infra/bicep/dns.bicep -p vnetAKSName=$vnetAKSName fqdnODAA=$fqdnODAA fqdnODAAApp=$fqdnODAAApp fqdnODAAIpv4=$fqdnODAAIpv4

# iterate via all zones and list all a records
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

## 📋 Steps

1. 🎯 Navigate to your Oracle ADB instance in the Azure Portal
2. 🔧 Locate the Network Security Group settings
3. ➕ Add the AKS VNet CIDR (e.g., `10.10.0.0/16`) to the allowed sources
4. 💾 Save the configuration
5. ✅ Test connectivity from AKS to verify the changes

[Back to workspace README](../../README.md)