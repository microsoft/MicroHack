# 🔐 Challenge 2: Update Oracle ADB NSG with AKS VNet CIDR

## 🌐 Network Security Group Configuration

You need to update the Oracle ADB NSG with the CIDR of the VNet where your AKS cluster is deployed. This can be done via the Azure Portal.

## 🔍 DNS Configuration

Also consider aligning your DNS configuration based on the Oracle documentation:
📚 [Network DNS Configuration Guide](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/network-dns.htm)

### Seperate ODAA Subscription

In case you did deploy your ODAA in a different Subscription as the one which does contain your AKS cluster, you will need to extract the ODAA FQDN and IP Address from the Azure Portal.

Afterwards you need to run the following bicep command to update your DNS configuration:

```bash
$rgAKS="ODAA" # replace with your AKS resource group name
$vnetAKSName="ODAA" # replace with your AKS resource group name
az deployment group create --resource-group $rgAKS --template-file resources/infra/bicep/dns.bicep -p vnetAKSName=$vnetAKSName
 fqdnODAA=<extracted-fqdn> fqdnODAAApp=<extracted-fqdn-app> fqdnODAAIpv4=<extracted-ipv4>
```

## 📋 Steps

1. 🎯 Navigate to your Oracle ADB instance in the Azure Portal
2. 🔧 Locate the Network Security Group settings
3. ➕ Add the AKS VNet CIDR (e.g., `10.10.0.0/16`) to the allowed sources
4. 💾 Save the configuration
5. ✅ Test connectivity from AKS to verify the changes
