# 🔌 Challenge 3: Perform Connectivity Tests

## 📋 Prerequisites

- 🔧 install Azure CLI
- ⚓ install kubectl
- 📦 install helm

## 🔐 Login to Azure and set the right subscription

~~~bash
az login --use-device-code
az account show
az account set -s <your-subscription-id>
~~~

## 🌍 Define required environment variables

~~~bash
rgName="<odaa-resource-group>"
prefix="<ODAA-prefix>"
location="<your-location>" # e.g. germanywestcentral
~~~

## ⚓ Connect to AKS

~~~bash
# login to aks
az aks get-credentials -g $rgName -n $prefix --overwrite-existing
# list namespaces
kubectl get namespaces # should show default, kube-system, kube-public
~~~

~~~text
NAME                STATUS   AGE
default             Active   10m
gatekeeper-system   Active   9m37s
kube-node-lease     Active   10m
kube-public         Active   10m
kube-system         Active   10m
~~~

## 📡 Ping Test from AKS to ODAA ADB

~~~bash
# use the C:\Users\chpinoto\workspace\cptdazodaa\mh\infra\k8s\network-test-pod.yaml to create a simple pod which we will use for ping test
kubectl apply -f mh/infra/k8s/network-test-pod.yaml
# login to the pod
kubectl exec -it network-test-pod -- /bin/bash
# do the ping to 10.0.0.5 in remote VNet
ping 10.0.0.5
exit
~~~

## 🔗 Connect to ADB via sqlplus from within the pod

To connect to the ADB instance you will need the connection string. You can retrieve it via the Azure Portal from the ODAA ADB instance or use the Azure CLI:

~~~bash
trgConn=$(az oracle-database autonomous-database show -g $rg -n $adbName --query "connectionStrings.profiles[?consumerGroup=='High' && protocol=='TCPS' && tlsAuthentication=='Server'].value | [0]" -o tsv)
echo $trgConn
~~~

~~~bash
kubectl get pods -n microhacks 
# login to the pod ogghack-goldengate-microhack-sample-instantclient-5985df84vc5xs
kubectl exec -it -n microhacks ogghack-goldengate-microhack-sample-instantclient-5985df842h84h -- /bin/bash
alias sql='sqlplus SH/Welcome1234#@//ogghack-goldengate-microhack-sample-db23ai:1521/FREEPDB1'
sql # connect to local db
exit

sqlplus admin@'<your-connection-string>'
<your-ADB-password>
exit
exit
~~~
