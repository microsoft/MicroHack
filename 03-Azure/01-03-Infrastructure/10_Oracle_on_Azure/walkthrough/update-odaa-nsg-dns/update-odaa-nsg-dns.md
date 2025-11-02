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

There are multiple ways to create the required DNS records within the Azure Private DNS Zones that are linked to the AKS VNet. We the following two ways how to set the Azure DNS zones:
1. By using Azure Bicep via Azure CLI.
2. By using the Azure portal directly


#### Azure Bicep to set the private DNS zones

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

#### Azure Portal to set the private DNS zones

1. From the overview portal of the deployed ADB database, copy the FQDN of the "Database URL name" and Database private IP address both in the section Network.
<img src="./media/prviate_dns_0.png" alt="Create browser profile" width="400" height="250" />  

1. Move to the AKS resource group (aks-user[assignedgroup number])
<img src="./media/private_dns_1.png" alt="Create browser profile" width="400" height="250" />

1. The private DNS name needs to be set on the following two private DNS names. 
   * adb.eu-paris-1.oraclecloud.com
   * adb.eu-paris-1.oraclecloudapps.com

    The following step is equal for both private DNS name. In the private DNS zone menu open the DNS management and press the link <b>Recodsets</b>.
    <img src="./media/private_dns_2.png" alt="Create browser profile" width="400" height="250" />

    <b>Important!</b> The other two Private DNS zones can be skipped for the moment till we need to set up ADB with high availability.

2. In the menue Recordsets press the Add button to add the FQDN and private ip address of the deployed ADB shared database.
    <img src="./media/private_dns_3.png" alt="Create browser profile" width="400" height="250" />

3. After you press the Add button a new window will be opened where the name for the ADB and the private IP address needs to be added. In addition change the TTL to 10 seconds.   
    <img src="./media/private_dns_4.png" alt="Create browser profile" width="250" height="300" />

4. Final save the configuration and repeat the step for the second private DNS name in the same way as described.    
   <img src="./media/private_dns_5.png" alt="Create browser profile" width="400" height="250" />
<br>

<hr>

[Back to workspace README](../../README.md)