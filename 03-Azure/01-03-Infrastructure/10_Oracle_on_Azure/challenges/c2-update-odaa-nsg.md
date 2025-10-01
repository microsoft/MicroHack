# 🔐 Challenge 2: Update Oracle ADB NSG with AKS VNet CIDR

## 🌐 Network Security Group Configuration

You need to update the Oracle ADB NSG with the CIDR of the VNet where your AKS cluster is deployed. This can be done via the Azure Portal.

## 🔍 DNS Configuration

Also consider aligning your DNS configuration based on the Oracle documentation:
📚 [Network DNS Configuration Guide](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/network-dns.htm)

## 📋 Steps

1. 🎯 Navigate to your Oracle ADB instance in the Azure Portal
2. 🔧 Locate the Network Security Group settings
3. ➕ Add the AKS VNet CIDR (e.g., `10.10.0.0/16`) to the allowed sources
4. 💾 Save the configuration
5. ✅ Test connectivity from AKS to verify the changes
