# 🔄 Challenge 4: Use GoldenGate to replicate data between an Oracle database running in AKS and the Oracle ADB instance

🌟 Oracle GoldenGate enables real-time data replication and integration across heterogeneous environments. In this microhack, GoldenGate is used to synchronize data between an Oracle database running in Azure Kubernetes Service (AKS) and an Oracle Autonomous Database (ADB) instance on Oracle Cloud Infrastructure (OCI), ensuring high availability and seamless data migration.

~~~powershell
# switch to the subscription where AKS is deployed
$subAKS="sub-1" # replace with your AKS subscription name
# Make sure your cli points to the AKS subscription
az account set --subscription $subAKS
# log into your AKS cluster if not already done
$rgAKS="odaa1" # replace with your AKS resource group name
$AKSClusterName="odaa1" # replace with your AKS cluster name
az aks get-credentials -g $rgAKS -n $AKSClusterName --overwrite-existing
# Install golden gate
helm repo add oggfree https://ilfur.github.io/VirtualAnalyticRooms
~~~

## 🔧 Replace current Goldengate configuration File gghack.yaml public IP of the nginx ingress controller

~~~powershell
# get the external IP of the ingress controller
$EXTIP = (kubectl get service -n ingress-nginx -o jsonpath='{range .items[*]}{.status.loadBalancer.ingress[*].ip} {end}') -replace '\s', ''
~~~

> ⚠️ **IMPORTANT**: Make sure the external IP of your nginx ingress controller is assigned.

~~~powershell
echo "External IP of the Ingress Controller: $EXTIP"
~~~

After you have the external IP address, replace the placeholder in the gghack.yaml file.

~~~powershell
cp resources/template/gghack.yaml .
(Get-Content gghack.yaml) -replace 'xxx-xxx-xxx-xxx', $EXTIP.Trim() | Set-Content gghack.yaml
code gghack.yaml
~~~

the value of vhostName should look like this:

~~~yaml
    ### typical ingressClasses are nginx and istio
    ingressClass: nginx
    ### uses default SSL certificate of gateway/controller or specify a custom tls-secret here
    tlsSecretName: ggate-tls-secret
    vhostName: gghack.4.182.95.155.nip.io
  internal:
    type: ClusterIP
    plainPort: 8080
    sslPort: 8443
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

~~~powershell
$adbName="odaa2" # replace with your ADB name
# Prerequisites (if not already installed)
az extension add --name oracle-database 

# Switch to the subscription where ODAA is deployed
$subODAA="ODAA" # replace with your ODAA subscription name
az account set --subscription $subODAA
$rgODAA="odaa2" # replace with your resource group name

# Retrieve TNS Connection string High profile (TCPS, tlsAuthentication = Server)
$trgConn=az oracle-database autonomous-database show -g $rgODAA -n $adbName --query "connectionStrings.profiles[?consumerGroup=='High' && protocol=='TCPS' && tlsAuthentication=='Server'].value | [0]" -o tsv
# replace in value in your gghack.yaml
(Get-Content gghack.yaml) -replace '<ODAA-CONNECTION-STRING>', $trgConn | Set-Content gghack.yaml
~~~

Your connection string in your gghack.yaml should look similar to this:

~~~yaml
databases:
  trgConn: "(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=gpdmotes.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_odaa2_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))"

  #for demo env, dont change the schema names. SH already exists in ADB, so we create another one.
  srcSchema: "SH"
  trgSchema: "SH2"
~~~

## 🚀 Install GoldenGate Microhack

There will be 3 different systems involved:

- GoldenGate (ogg-admin-secret)
 - GoldenGate Admin User: ggadmin
- Source Database oracle 23ai free edtion
 - Admin User: system (db-admin-secret), ggadmin (srcGGUserName)
- Target Database ODAA ADB
 - Admin User: admin (db-admin-secret), ggadmin (trgGGUserName)

> IMPORTANT: The password for all users must be the same for simplicity and must match the password you defined during the creation of the ODAA ADB instance.

~~~powershell
# switch to the subscription where AKS is deployed
$subAKS="sub-1" # replace with your AKS subscription name
# Make sure your cli points to the AKS subscription
az account set --subscription $subAKS
# Define the password which will be used for all three systems
$password="Welcome1234#"
# create the namespace everything goes into
kubectl create namespace microhacks
#create secret for Golden Gate OGG admin user and password to-be-created
kubectl create secret generic ogg-admin-secret -n microhacks --from-literal=oggusername=ggadmin --from-literal=oggpassword=$password
#create secret for source and target database admin and ogg users to be created (target must be there already! ODAA ADB in Azure)
kubectl create secret generic db-admin-secret -n microhacks --from-literal=srcAdminPwd=$password --from-literal=trgAdminPwd=$password --from-literal=srcGGUserName=ggadmin --from-literal=trgGGUserName=ggadmin --from-literal=srcGGPwd=$password --from-literal=trgGGPwd=$password
# Verify secrets and display them (passwords will be hidden)
kubectl get secrets -n microhacks -o json
# decode secretes for verification (passwords will be visible here)
# Decode ogg-admin-secret password
[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(
    (kubectl get secret ogg-admin-secret -n microhacks -o jsonpath="{.data.oggpassword}")
))

# Decode db-admin-secret srcAdminPwd
[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(
    (kubectl get secret db-admin-secret -n microhacks -o jsonpath="{.data.srcAdminPwd}")
))

# Decode db-admin-secret trgAdminPwd
[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(
    (kubectl get secret db-admin-secret -n microhacks -o jsonpath="{.data.trgAdminPwd}")
))
~~~

~~~json
{
    "apiVersion": "v1",
    "items": [
        {
            "apiVersion": "v1",
            "data": {
                "srcAdminPwd": "V2VsY29tZTEyMzQj",
                "srcGGPwd": "V2VsY29tZTEyMzQj",
                "srcGGUserName": "Z2dhZG1pbg==",
                "trgAdminPwd": "V2VsY29tZTEyMzQj",
                "trgGGPwd": "V2VsY29tZTEyMzQj",
                "trgGGUserName": "Z2dhZG1pbg=="
            },
            "kind": "Secret",
            "metadata": {
                "creationTimestamp": "2025-10-21T12:36:13Z",
                "name": "db-admin-secret",
                "namespace": "microhacks",
                "resourceVersion": "1683911",
                "uid": "e79273e7-7e52-41a9-a536-ef1545e5e742"
            },
            "type": "Opaque"
        },
        {
            "apiVersion": "v1",
            "data": {
                "oggpassword": "V2VsY29tZTEyMzQj",
                "oggusername": "Z2dhZG1pbg=="
            },
            "kind": "Secret",
            "metadata": {
                "creationTimestamp": "2025-10-21T12:35:55Z",
                "name": "ogg-admin-secret",
                "namespace": "microhacks",
                "resourceVersion": "1683829",
                "uid": "3d2a135b-b19b-4a04-be8e-be1d86e5e3e2"
            },
            "type": "Opaque"
        }
    ],
    "kind": "List",
    "metadata": {
        "resourceVersion": ""
    }
}
~~~

Install all components via Helm:

~~~powershell
helm install ogghack oggfree/goldengate-microhack-sample --values gghack.yaml -n microhacks
~~~

📄 You should see a similar output:

~~~text
NAME: ogghack
LAST DEPLOYED: Tue Oct 21 15:58:24 2025
NAMESPACE: microhacks
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Final NOTES:

Please wait about 2 Minutes for the source database to be completely up and loaded.

You can already try out Your sqlplus command line by using this URL in Your browser:
https://gghack.4.182.95.155.nip.io/sqlplus/vnc.html

Alternatively, have a look at Your personal jupyter notebook:
https://gghack.4.182.95.155.nip.io/jupyter/
Just enter the password "Welcome1234" when asked and then open the CPAT analysis notebook.

Once the DB is ready, GOldenGate Sync should be set up too. Check it out right here:
https://gghack.4.182.95.155.nip.io

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
ogghack-goldengate-microhack-sample-db-5f9ccf59dc-wtcmf           1/1     Running     0          62m
ogghack-goldengate-microhack-sample-db-prepare-job-pzncs          0/1     Completed   0          62m
ogghack-goldengate-microhack-sample-instantclient-5985df84lcjwx   1/1     Running     0          62m
ogghack-goldengate-microhack-sample-jupyter-69d77b895b-4b7g8      1/1     Running     0          62m
ogghack-goldengate-microhack-sample-ogg-787f954698-kzjpl          1/1     Running     0          62m
~~~

✅ After the job is completed, the local database, which is running inside the AKS cluster, has been migrated to the ODAA ADB instance via GoldenGate.

## Tips and Tricks

### Redeploy if things go wrong

~~~powershell
# login to aks
az aks get-credentials -g $rgAKS -n $AKSClusterName --overwrite-existing
# Uninstall the Helm release
helm uninstall ogghack -n microhacks
# Delete the namespace, if you do so you will need to recreate the secrets again
kubectl delete namespace microhacks
~~~

### Show the logs of the GoldenGate Prepare Job

~~~powershell
# login to aks if not already done
az aks get-credentials -g $rgAKS -n $AKSClusterName --overwrite-existing
# get prep job pod name
$podPrepName = kubectl get pods -n microhacks | Select-String 'ogghack-goldengate-microhack-sample-db-prepare-job' | ForEach-Object { ($_ -split '\s+')[0] }
kubectl logs -n microhacks $podPrepName
~~~

~~~text
Defaulted container "dbhelper" out of: dbhelper, dbcheck (init)
Cloning into 'gg_microhacks_scripts'...
ADP=(description=(retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=gpdmotes.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_odaa2_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))

SQL*Plus: Release 23.0.0.0.0 - Production on Tue Oct 21 14:02:31 2025
Version 23.4.0.24.05

Copyright (c) 1982, 2024, Oracle.  All rights reserved.

Last Successful login time: Tue Oct 21 2025 13:30:17 +00:00

Connected to:
Oracle Database 23ai Enterprise Edition Release 23.0.0.0.0 - for Oracle Cloud and Engineered Systems
Version 23.10.0.25.10

SQL>
User altered.

SQL>   2    3    4    5    6    7
PL/SQL procedure successfully completed.

SQL>   2    3    4    5    6    7    8    9   10   11   12   13   14   15   16   17   18   19   20   21   22   23   24   25   26
PL/SQL procedure successfully completed.

SQL> Disconnected from Oracle Database 23ai Enterprise Edition Release 23.0.0.0.0 - for Oracle Cloud and Engineered Systems
Version 23.10.0.25.10
Cloning into 'db-sample-schemas'...


...
~~~

### Connect to the ADB Oracle Database

~~~powershell
# login to aks if not already done
az aks get-credentials -g $rgAKS -n $AKSClusterName --overwrite-existing
# extract the pod name of the instantcleint as it contains a random suffix
$podInstanteClientName=kubectl get pods -n microhacks | Select-String 'ogghack-goldengate-microhack-sample-instantclient' | ForEach-Object { ($_ -split '\s+')[0] }
# login to the pod ogghack-goldengate-microhack-sample-instantclient-5985df84vc5xs
kubectl exec -it -n microhacks $podInstanteClientName -- /bin/bash
# log into ADB with admin via sqlplus, replace the TNS connection string with your own
sqlplus admin@'(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=gpdmotes.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_odaa2_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))'
# This will be the password you defined for variable $password
Welcome1234# # replace with your ADB password
~~~

~~~sql
select USERNAME from ALL_USERS where USERNAME like 'SH%';
~~~

~~~text
USERNAME
--------------------------------------------------------------------------------
SH
SH2
~~~

~~~sql
-- should return 35 rows
select COUNT (*) from SH2.COUNTRIES;
~~~

~~~text
  COUNT(*)
----------
        35
~~~

Verify SH user and GGADMIN user in ADB

~~~sql
select USERNAME from ALL_USERS where USERNAME like 'SH%';
~~~

~~~text
USERNAME
--------------------------------------------------------------------------------
SH
SH2
~~~

~~~sql
select USERNAME, ACCOUNT_STATUS from DBA_USERS where USERNAME like 'GGADMIN';
~~~

~~~text
USERNAME
--------------------------------------------------------------------------------
ACCOUNT_STATUS
--------------------------------
GGADMIN
OPEN
~~~