# 🔄 Challenge 4: Use GoldenGate to replicate data between an Oracle database running in AKS and the Oracle ADB instance

🌟 Oracle GoldenGate enables real-time data replication and integration across heterogeneous environments. In this microhack, GoldenGate is used to synchronize data between an Oracle database running in Azure Kubernetes Service (AKS) and an Oracle Autonomous Database (ADB) instance on Oracle Cloud Infrastructure (OCI), ensuring high availability and seamless data migration.

~~~bash
# Install golden gate
helm repo add oggfree https://ilfur.github.io/VirtualAnalyticRooms
~~~

## 🔧 Replace current Goldengate configuration File gghack.yaml public IP of the nginx ingress controller

> ⚠️ **IMPORTANT**: Make sure to use the external IP of your nginx ingress controller is assigned.

~~~bash
export EXTIP=$(kubectl get service -n ingress-nginx -o jsonpath='{range .items[*]} {.status.loadBalancer.ingress[*].ip} {end}')
cp resources/template/gghack.yaml .
sed -i "s/xxx-xxx-xxx-xxx/${EXTIP// /}/g" gghack.yaml
~~~

## 🔗 Replace current Goldengate configuration File gghack.yaml ODAA connection String

📍 Retrieve the connection string via the Azure Portal from the ODAA ADB instance.

1. 🎯 Go to your Oracle Database in Azure Portal, search for "adb" in the search bar on top.
2. 🔍 Select "Oracle Database@Azure" from the search results.
3. 📋 Select "Oracle Autonomous Database Service" from the left menu.
4. 🎪 Select your created ADB instance.
5. 🔗 Select "Connection" from the left menu.
6. 🔒 Select high, TLS Authentication=TLS Connection String

🔧 Alternative you can use the Azure CLI to retrieve the connection string.

~~~bash
adbName="ADBGer" # replace with your ADB name
# Prerequisites (if not already installed)
az extension add --name oracle-database 

# High profile (TCPS, tlsAuthentication = Server) - returns first match
trgConn=$(az oracle-database autonomous-database show -g $rg -n $adbName --query "connectionStrings.profiles[?consumerGroup=='High' && protocol=='TCPS' && tlsAuthentication=='Server'].value | [0]" -o tsv)
echo $trgConn
sed -i "s/<ODAA-CONNECTION-STRING>/${trgConn}/g" gghack.yaml
~~~

## 🚀 Install GoldenGate Microhack

> ⚠️ **IMPORTANT**: Make sure to use the same password on the ADB as mentioned here.

~~~bash
ggAdminPassword=Welcome1234#
# create the namespace everything goes into
kubectl create namespace microhacks
#create secret for OGG admin user and password to-be-created
kubectl create secret generic ogg-admin-secret -n microhacks --from-literal=oggusername=ggadmin --from-literal=oggpassword=$ggAdminPassword
#create secret for source and target database admin and ogg users to be created (target must be there already! ODAA ADB in Azure)
kubectl create secret generic db-admin-secret -n microhacks --from-literal=srcAdminPwd=$ggAdminPassword --from-literal=trgAdminPwd=$ggAdminPassword --from-literal=srcGGUserName=ggadmin --from-literal=trgGGUserName=ggadmin --from-literal=srcGGPwd=$ggAdminPassword --from-literal=trgGGPwd=$ggAdminPassword
helm install ogghack oggfree/goldengate-microhack-sample --values gghack.yaml -n microhacks
~~~

📄 You should see a similar output:

~~~text
NAME: ogghack
LAST DEPLOYED: Thu Sep 25 18:50:00 2025
NAMESPACE: microhacks
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Final NOTES:

Please wait about 2 Minutes for the source database to be completely up and loaded.

You can already try out Your sqlplus command line by using this URL in Your browser:
https://gghack.131.189.139.184.nip.io/sqlplus/vnc.html

Alternatively, have a look at Your personal jupyter notebook:
https://gghack.131.189.139.184.nip.io/jupyter/
Just enter the password "Welcome1234" when asked and then open the CPAT analysis notebook.

Once the DB is ready, GOldenGate Sync should be set up too. Check it out right here:
https://gghack.131.189.139.184.nip.io

Have fun !
~~~

## ⏳ Wait until all pods are in status "Running"

~~~bash
kubectl get pods -n microhacks --watch
~~~

⏰ Wait until the ogghack-goldengate-microhack-sample-db-prepare-job is completed and exit the watch with Ctrl+C.

> ℹ️ **NOTE**: Error and CrashLoopBackOff of the ogghack-goldengate-microhack-sample-db-prepare-job pod is expected.

📊 The output should look similar to this after the job is completed:

~~~text
NAME                                                              READY   STATUS      RESTARTS   AGE
ogghack-goldengate-microhack-sample-db-5f9ccf59dc-g9f2q           1/1     Running     0          11m
ogghack-goldengate-microhack-sample-db-prepare-job-8p94v          0/1     Completed   0          11m
ogghack-goldengate-microhack-sample-instantclient-5985df846htkl   1/1     Running     0          11m
ogghack-goldengate-microhack-sample-jupyter-5ff8b584ff-zchk8      1/1     Running     0          11m
ogghack-goldengate-microhack-sample-ogg-787f954698-zlgg5          1/1     Running     0          11m
~~~

✅ After the job is completed, the local database, which is running inside the AKS cluster, has been migrated to the ODAA ADB instance via GoldenGate.
