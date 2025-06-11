## challenges3 (Oracle to PostgreSQL)

~~~bash
# in case you are at the root folder of the repository switch to the terraform folder
cd ./03-Azure/01-03-Infrastructure/10_Oracle_on_Azure/resources/challenge-3/kafka/terraform
# login with an user with the necessary permissions
az login --use-device-code
# set the subscription
az account set -s coach1
# Make sure you have the right extensions installed on azure cli
az extension add --name containerapp --upgrade
# Make sure the necessary providers are registered on the subscription
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
# define the prefix for the resources and make sure to configure it accordingly on the terraform.tfvars file.
$prefix="maikmh"
# inside the terraform folder initialize the terraform configuration
terraform init
terraform fmt
terraform validate
terraform plan -out plan1.out
terraform apply --auto-approve plan1.out 


# show 
az containerapp show --resource-group $prefix --name  "${prefix}-kafka" --output json

# list and verify the deployed container apps and resource group
az containerapp list -g $prefix --query "[].{name:name}" -o table

# test connectivity from zookeeper to kafka
nc -zv ora2pg-kafka 9092 # Ncat: Connected to 100.100.248.118:9092.
exit

# Check if the container name within the container app is correct.
az containerapp show --name "${prefix}-ora2pg" -g $prefix --query "properties.template.containers[].name" -o table

#Result
#--------
#ora2pg

# Check if the container app is running.
az containerapp show --name "${prefix}-ora2pg" -g $prefix --query "properties.provisioningState" -o table

#Result
#---------
#Succeeded

# Check the log files of the container app
az containerapp logs show --name "${prefix}-ora2pg" -g $prefix --container ora2pg

# connect on the container app
az containerapp exec --name "${prefix}-ora2pg" -g $prefix --container ora2pg --command bash


# test connectivity from kafka to zookeeper
az containerapp exec --name "${prefix}-kafka" -g $prefix --container kafka --command bash
nc -zv maikmh-zookeeper 2181 # Ncat: 0 bytes sent, 0 bytes received in 0.04 seconds.
exit

# test azure file share access from kafka connect container
az containerapp exec --name "${prefix}-kafka-connect" -g $prefix --container kafka-connect --command bash
df -h
cd /mnt/azurefile
ls
cat spiderman.txt
exit
~~~
az containerapp exec --name "${prefix}-zookeeper" -g $prefix --container zookeeper --command bash

