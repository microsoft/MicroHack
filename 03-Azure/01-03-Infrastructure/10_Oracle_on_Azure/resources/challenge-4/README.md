# Migrate to Oracle Database at Azure

## Introduction

In the last challenge we are going to have a look at the new Azure Service called "Oracle DatabaseAzure" [ODAA].

Oracle Database@Azure is an Oracle database service running on Oracle Cloud Infrastructure (OCI), colocated in Microsoft data centers. This ensures that the Oracle Database@Azure service has the fastest possible access to Azure resources and applications.

Oracle Database@Azure allows you to subscribe to the Oracle Database Service inside your Azure environment. All infrastructure for your Oracle Database Service is located in Azure's physical data centers, giving your critical database workloads the high-performance and low-latency they require. Like other Azure services, Oracle Database@Azure uses an Azure Virtual Network for networking, managed within the Azure environment. The service uses the Azure tenancy's identity management and authorization, which can be either the Azure native identity service or a federated identity provider. The service allows you to monitor database metrics, audit logs, events, logging data, and telemetry natively in Azure.

Oracle Database@Azure runs on infrastructure managed by Oracle's expert Cloud Infrastructure operations team. The operations team performs software patching, infrastructure updates, and other operations through a connection to OCI. While the service requires that customers have an OCI tenancy, most service activities take place in the Azure environment.

ODAA comes in two flavors:

1. [Autonomous Database Services](https://docs.oracle.com/en-us/iaas/Content/database-at-azure-autonomous/odadb-autonomous-database-services.html)
2. [Exadata Services](https://docs.oracle.com/en-us/iaas/Content/database-at-azure-exadata/odexa-exadata-services.html)

During this challenge we are going to use the [Autonomous Database Services](https://docs.oracle.com/en-us/iaas/Content/database-at-azure-autonomous/odadb-autonomous-database-services.html) and use an already created Autonomous Database.

~~~mermaid
classDiagram
  class vWAN {
    Location: swedencentral
  }
  class vHub {
    CIDR : 10.42.0.0/16
    Location: swedencentral
  }
  class SpokeVNetODAA{
    CIDR : 172.16.0.0/16
    Location: germanywestcentral
  }
  class SpokeVNetOnprem{
    CIDR : 10.0.0.0/16
    Location: swedencentral
    Bastion: bastion
  }
  class SubnetTeam1{
    CIDR : 10.1.0.0/24
    Location: swedencentral
    Bastion: bastion
  }
  class SubnetTeam2{
    CIDR : 10.2.0.0/24
    Location: swedencentral
    Bastion: bastion
  }
  class SubnetTeam3{
    CIDR : 10.3.0.0/24
    Location: swedencentral
    Bastion: bastion
  }
  class SubnetODAA{
    CIDR : 172.16.0.0/24
    Location: germanywestcentral
    ODAA: odaa1,odaa2,odaa3
  }
  vWAN -- vHub
  vHub -- SpokeVNetODAA : vwan-peering
  vHub -- SpokeVNetOnprem : vwan-peering
  SpokeVNetOnprem -- SubnetTeam1
  SpokeVNetOnprem -- SubnetTeam2
  SpokeVNetOnprem -- SubnetTeam3
  SpokeVNetODAA -- SubnetODAA
~~~

## Create vWAN Connectivity between ODAA and on-premise 

One of the benefits of using ODAA is the low latency between the ODAA and the on-premise environment. To make things a little bit more challenging, let's assume we need to create ODAA in a different region than the on-premise environment.

### Create an ODAA in a different region than the on-premise environment

In this task we are going to create an ODAA in a different region than the on-premise environment together with the trainer.

> Goal: Understand how to create an ODAA Autonomous DB. 
> NOTE: The Autonomous DB is already created for you.

Links:
- https://docs.oracle.com/en-us/iaas/Content/database-at-azure/oaaonboard.htm

### Create an vWAN connection to ODAA on-premise

This setup has been already prepared for you. The task here is to discuss the setup and understand how it works together with your trainer.

> Goal: Make yourself familar with the network setup and understand how the ODAA is connected to the on-premise environment.

Links:

- https://learn.microsoft.com/en-us/azure/oracle/oracle-db/oracle-database-network-plan
- https://docs.oracle.com/en-us/iaas/Content/database-at-azure/oaa-troubleshooting.htm#

### Create an VM inside your Onprem VNet and connect to ODAA

Here you will need to setup an Linux Azure VM and install the sqlplus client.
You will need to retrieve the connection string from the ODAA and connect to the ODAA using the sqlplus client.

> Goal: Connect to the ODAA using the sqlplus client.

### Migrate the database to ODAA with Zero Downtime Migration from Oracle (Optional)

Follow the instruction at the two following links to create the ODAA and migrate the database:

- [Oracle Database at Azure migration overview by oracle](https://docs.oracle.com/en/solutions/oracle-db-at-azure-migration/index.html#GUID-54E96CD1-06E9-4D82-B8EC-DCF919C32557)
- [Oracle Zero Downtime Migration – Logical Offline Migration to ADB-S on Oracle Database@Azure by oracle](https://www.oracle.com/a/otn/docs/database/zdm-logical-offline-migration-to-oracle-at-azure-adb-s.pdf)

> Goal: Migrate the database to ODAA with Zero Downtime Migration from Oracle.
> NOTE: This task is optional and will not be graded.

## Solution

~~~powershell
az login --use-device-code
$subName="build"
az account set -s $subName
$rgName="rg-mh-oracle-1"
$zdmVmName="zdm2"
$zdmVMId=az vm show -g $rgName -n $zdmVmName --query id -o tsv
$bastionName=az network bastion list -g $rgName --query "[0].name" -o tsv
az network bastion ssh --name $bastionName -g $rgName --target-resource-id $zdmVMId --auth-type password --username chpinoto
demo!pass123
~~~

### Inside the zdm VM

~~~bash
# Verify the running Oracle Linux version
cat /etc/os-release # Minimum OS version Oracle Linux 7

# Install sqlplus
wget https://download.oracle.com/otn_software/linux/instantclient/2370000/oracle-instantclient-basic-23.7.0.25.01-1.el8.x86_64.rpm
sudo rpm -ivh oracle-instantclient-basic-23.7.0.25.01-1.el8.x86_64.
wget https://download.oracle.com/otn_software/linux/instantclient/2370000/oracle-instantclient-sqlplus-23.7.0.25.01-1.el8.x86_64.rpm
sudo rpm -ivh oracle-instantclient-sqlplus-23.7.0.25.01-1.el8.x86_64.rpm
# verify if sqlplus has been installed
sqlplus -v

# create tnsnames.ora config file
echo "odaa2=(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=vvtqclsd.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g74e1d79d80e6af_odaa2_low.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))" | tnsnames.ora
cat tnsnames.ora

# verify if the FQDN does use a public IP
dig vvtqclsd.adb.eu-frankfurt-1.oraclecloud.com
mkdir -p /usr/lib/oracle/23/client64/lib/network/admin
sudo cp tnsnames.ora /usr/lib/oracle/23/client64/lib/network/admin
cat /usr/lib/oracle/23/client64/lib/network/admin/tnsnames.ora

# connect to ODAA
sqlplus admin@odaa2
<REPLACE-W-YOUR-PASSWORD>
~~~
