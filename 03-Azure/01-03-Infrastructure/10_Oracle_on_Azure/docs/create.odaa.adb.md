# 🚀 Oracle Database @ Azure (ODAA) - Deployment Scripts for ADB

### 🔐 Login to Azure and set the right subscription

~~~powershell
az login --use-device-code
az account show
az account set -s "ODAA"
# Register required providers for odaa
# TBD: Check if all are required
az provider register --namespace "Microsoft.Oracle"
az provider register --namespace "Microsoft.Baremetal"
az provider register --namespace "Microsoft.Network"
~~~

### 🌍 Define some environment variables

~~~powershell
$prefix="odaa"
$postfix="1"
$location="francecentral"
$password = Read-Host -Prompt "Enter the shared password"
$cidr="10.0.0.0"
~~~

### 🏗️ Create Azure Resources

> ℹ️ **NOTE:** This would be created manually during the workshop.

~~~bash
az deployment sub create -n $prefix -l $location -f ./resources/infra/bicep/odaa/main.bicep -p location=$location prefix=$prefix postfix=$postfix password=$password cidr=$cidr
# Verify the created resources, list all resource inside the resource group
az resource list -g $rgName -o table --query "[].{Name:name, Type:type}"
~~~

~~~text
~~~
