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

<font color=red> <b>Important:</b> We need to query the Private DNS Zones created with the <b>ODAA deployment</b>.</font>

~~~powershell

# switch to the corresponding subscription where ODAA is deployed
$subODAA="sub-mhodaa" # replace with your ODAA subscription name
az account set -s $subODAA
$rgODAA="odaa-shared" # replace with your ODAA resource group name

$zones = az network private-dns zone list -g $rgODAA --query "[].name" -o tsv
echo $zones
~~~

<br>

~~~text
gpdmotes.adb.eu-paris-1.oraclecloud.com
gpdmotes.adb.eu-paris-1.oraclecloudapps.com
~~~

<br>

If you only see the domains in $zones
* adb.eu-paris-1.oraclecloud.com, 
* adb.eu-paris-1.oraclecloudapps.com
  
you need to change to the ODAA subscription by repeting the upper commands! Because all ODAA databases are deployed in the same shared delegated subnet copy the <font color=red>right</font> FQDN's of your deployed databases!

<br>

<hr>

### Create AKS DNS Records

There are multiple ways to create the required DNS records within the Azure Private DNS Zones that are linked to the AKS VNet. We the following two ways how to set the Azure DNS zones:
1. By using Azure Bicep via Azure CLI.
2. By using the Azure portal directly

<br>

#### Azure Bicep to set the private DNS zones

In the first step you have to create a Network Security Group called NSG on the Oracle OCI side. The following steps show you the required steps how to add an NSG of the deployed ADB, so that the AKS cluster is able to connect the database. 

1. Move in the Azure portal to your AKS subscription and resoucre group where your aks cluster is deployed. Inside the resource group you will find the aks related vnet. Copy in the overview "address space" the CIDR of the vnet. <br>
In our case the "address space" should be 10.1.0.0/16
<br><img src="./media/OCI_nsg5.jpg" alt="Create browser profile" width="450" height="180" />

2. In the second step connect to the OCI console by using the federation via Entra ID. After you logged in use the hamburger Icon in ther upper left corner and press the menue "Oracle AI databases".
<br><img src="./media/OCI_nsg1.jpg" alt="Create browser profile" width="450" height="180" />

3. Press on the link of your deployed ADB database and scroll down to the networking section on the ADB homepage.
<br><img src="./media/OCI_nsg2.jpg" alt="Create browser profile" width="450" height="200" />

4. Press on the link "Network Security Groups" to reach the NSG page. Under the Tab "Security Rules" you have to press the "Add Rules" button to add an ingress rule.
<br><img src="./media/OCI_nsg3.jpg" alt="Create browser profile" width="450" height="200" /> 

5. Choose in the Rule as "Source Type" CIDR and add the copied vnet address space of the previous AKS cluster into the field. Finally save the Rule
br><img src="./media/OCI_nsg4.jpg" alt="Create browser profile" width="450" height="200" />


<br>
<br>

Before you continue please verfiy the correct regions of the AKS and ODAA / ADB is used!

~~~powershell
# switch back to the subscription where AKS is deployed
$subAKS="sub-mh1" # replace with your AKS subscription name
az account set -s $subAKS
$fqdnODAA = 'dimm5zbj.adb.eu-paris-1.oraclecloud.com' # replace with your ODAA FQDN
$fqdnODAAApp = 'dimm5zbj.eu-paris-1.oraclecloudapps.com' # replace with your ODAA FQDN
$fqdnODAAIpv4 = '192.168.0.139' # replace with your ODAA private IP address
$rgAKS="aks-user01" # replace with your AKS resource group name
$vnetAKSName="aks-user01" # replace with your AKS resource group name


# iterate through all zones and list all A records
$zones = az network private-dns zone list --resource-group $rgAKS --query "[].name" -o tsv
foreach ($zone in $zones) {
    Write-Host "Listing A records for zone: $zone"
    az network private-dns record-set a list --zone-name $zone --resource-group $rgAKS --query "[].{Name:name, Records:aRecords[0].ipv4Address}" -o table
}
~~~

~~~text
Listing A records for zone: adb.eu-frankfurt-1.oraclecloud.com

Listing A records for zone: adb.eu-frankfurt-1.oraclecloudapps.com

Listing A records for zone: gpdmotes.eu-paris-1.oraclecloud.com.com
Name    Records
------  ----------
@       10.0.0.213
Listing A records for zone: gpdmotes.eu-paris-1.oraclecloudapps.com
Name    Records
------  ----------
@       10.0.0.213
~~~

#### Azure Portal to set the private DNS zones

1. From the overview portal of the deployed ADB database, copy the FQDN of the "Database URL name" and Database private IP address both in the section Network.
    <br>
    <img src="./media/prviate_dns_0.png" alt="Create browser profile" width="400" height="250" />  

2. Move to the AKS resource group (aks-user[assignedgroup number])
    <br>
    <img src="./media/private_dns_1.png" alt="Create browser profile" width="400" height="250" />

3. The private DNS name needs to be set on the following two private DNS names. 
   * adb.eu-paris-1.oraclecloud.com
   * adb.eu-paris-1.oraclecloudapps.com

    The following step is equal for both private DNS name. In the private DNS zone menu open the DNS management and press the link <b>Recodsets</b>.
    <br>
    <img src="./media/private_dns_2.png" alt="Create browser profile" width="400" height="250" />

    <b>Important!</b> The other two Private DNS zones can be skipped for the moment till we need to set up ADB with high availability.

4.  In the menue Recordsets press the Add button to add the FQDN and private ip address of the deployed ADB shared database.
   <br>
    <img src="./media/private_dns_3.png" alt="Create browser profile" width="400" height="250" />


5. After you press the Add button a new window will be opened where the name for the ADB and the private IP address needs to be added. In addition change the TTL to 10 seconds.   
    <img src="./media/private_dns_4.png" alt="Create browser profile" width="250" height="300" />


6. Final save the configuration and repeat the step for the second private DNS name in the same way as described.
    <br>
    <img src="./media/private_dns_5.png" alt="Create browser profile" width="400" height="250" />
<br>

<hr>

[Back to workspace README](../../README.md)