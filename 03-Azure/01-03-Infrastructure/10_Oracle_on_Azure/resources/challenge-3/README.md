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
$prefix="ora2pg"
# inside the terraform folder initialize the terraform configuration
tf init
tf fmt
tf validate
tf plan -out plan1.out
tf apply --auto-approve plan1.out 

# test connectivity from zookeeper to kafka
az containerapp exec --name "${prefix}-zookeeper" -g $prefix --container zookeeper --command bash
nc -zv ora2pg-kafka 9092 # Ncat: Connected to 100.100.248.118:9092.
exit

# test connectivity from kafka to zookeeper
az containerapp exec --name "${prefix}-kafka" -g $prefix --container kafka --command bash
nc -zv ora2pg-zookeeper 2181 # Ncat: 0 bytes sent, 0 bytes received in 0.04 seconds.
exit

# test azure file share access from kafka connect container
az containerapp exec --name "${prefix}-kafka-connect" -g $prefix --container kafka-connect --command bash
df -h
cd /mnt/azurefile
ls
cat spiderman.txt
exit
~~~
