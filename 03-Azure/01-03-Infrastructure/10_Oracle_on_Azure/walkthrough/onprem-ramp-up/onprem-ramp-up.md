# 🔄 Challenge 4: OnPrem ramp up

[Back to workspace README](../../README.md)

After you successfully created the ODAA Autonomous Database instance, you will now setup Oracle Data Pump and GoldenGate to replicate data from an on-premises Oracle database running in Azure Kubernetes Service (AKS) to the ODAA ADB instance.

Before you continue with the challenge verify that the Adress space 

We will install the following components into the AKS cluster under the Namespace "microhacks" via helm:

- Oracle Database (prefilled with the Schema SH1)
- Oracle Data Pump to import the SH1 schema into the ODAA ADB instance as SH2 schema
- Oracle GoldenGate to replicate data changes from SH1 schema to SH2 schema in near real-time
- Oracle Instant Client to connect to the ODAA ADB instance via sqlplus

## 📦 What is Kubernetes Helm?

Helm is a package manager for Kubernetes that allows you to define, install, and manage Kubernetes applications. It uses a packaging format called charts, which are collections of pre-configured Kubernetes resources.

## 🔐 Login to Azure and set the right subscription

~~~bash
az login --use-device-code
# make sure you select the subscription which starts with "sub-team", do not choose the subscription called "sub-mhodaa".
# Assign the subscription name to a variable
$subAKS="sub-mh0" # Replace with your Subscription Name.
~~~

## 🌍 Define required environment variables

~~~bash
# log into your AKS cluster if not already done
$rgAKS="aks-user00" # replace with your AKS resource group name
$AKSClusterName="aks-user00" # replace with your AKS cluster name
~~~

## ⚓ Connect to AKS

~~~bash
# login to aks
az aks get-credentials -g $rgAKS -n $AKSClusterName --overwrite-existing
~~~

## 🛠️ Install OnPrem on AKS with helm

~~~powershell
# Install golden gate
helm repo add oggfree https://ilfur.github.io/VirtualAnalyticRooms
# Do an update to get the newest chart templates
helm repo update
~~~

## 🔧 Replace Goldengate configuration File User Name in gghack.yaml


~~~powershell
# retrieve the external IP of the nginx ingress controller
$UserName = "user00" # replace with your user name
# create a copy of the template file
cp resources/template/gghack.yaml .
# replace the placeholder with the actual external IP
(Get-Content gghack.yaml) -replace '<USER-NAME>', $UserName.Trim() | Set-Content gghack.yaml
# show line 44 till 50 with powershell of gghack.yaml
(Get-Content gghack.yaml)[0..3]
~~~

The value of vhostName should look like this:

~~~yaml
microhack:
  user: user00
### specify the name of an existing secret that contains the ogg admin username and password
~~~

## 🔧 Replace Goldengate configuration File Ingress Public IP in gghack.yaml

We are already running an nginx ingress controller in the AKS cluster to provide access from outside the cluster to the GoldenGate microhack application.

~~~powershell
# retrieve the external IP of the nginx ingress controller
$EXTIP = (kubectl get service -n ingress-nginx -o jsonpath='{range .items[*]}{.status.loadBalancer.ingress[*].ip} {end}') -replace '\s', ''
echo "External IP of the Ingress Controller: $EXTIP"
~~~

After you have the external IP address, replace the placeholder in the gghack.yaml file.

~~~powershell
# replace the placeholder with the actual external IP
(Get-Content gghack.yaml) -replace '<INGRESS-PUBLIC-IP>', $EXTIP.Trim() | Set-Content gghack.yaml
# show line 44 till 50 with powershell of gghack.yaml
(Get-Content gghack.yaml)[42..57]
~~~

The value of vhostName should look like this:

~~~yaml
services:
  ### You can choose to create an ingress in front of the service 
  ### with a virtual host name of ggate.<suffix>
  external:
    ### set type to either ingress or none if You need something customized
    type: ingress
    ### typical ingressClasses are nginx and istio
    ingressClass: nginx
    ### uses default SSL certificate of gateway/controller or specify a custom tls-secret here
    tlsSecretName: ggate-tls-secret
    vhostName: gghack.4.251.147.64.nip.io # public IP address of
  internal:
    type: ClusterIP
    plainPort: 8080
    sslPort: 8443
~~~

## 🔗 Replace Goldengate configuration File gghack.yaml ODAA TNS connection String

Reference the document [How to retrieve the Oracle Database Autonomous Database connection string from ODAA](../../docs/odaa-get-token.md) to get the TNS connection string for your ODAA ADB instance.

⚠️ **Important**: If you follow the instructions in `docs\odaa-get-token.md`, remember to switch back to your AKS subscription after retrieving the TNS connection string:

After you have retrieved the TNS connection string and assigned it to the `$trgConn` variable (as shown in docs\odaa-get-token.md), replace the placeholder in the gghack.yaml file:

~~~powershell
# If you did follow the instruction the following line is not needed because $trgConn is already defined 
$trgConn="(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=xsbkef2g.adb.eu-paris-1.oraclecloud.com))(connect_data=(service_name=gc2401553d1c7ab_user00_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))"
# replace in value in your gghack.yaml
(Get-Content gghack.yaml) -replace '<ODAA-CONNECTION-STRING>', $trgConn | Set-Content gghack.yaml
# show line 8 till 11 with powershell of gghack.yaml
(Get-Content gghack.yaml)[10..13]
~~~

Your connection string in your gghack.yaml should look similar the yaml below. If the connection string is not copied successful into the gghack.yaml file you can do it manually as well be copy to connection string from the ADB Azure Portal und connections. Choose the connection for high.


~~~yaml
databases:
  # value for source database (23ai free container) is calculated.
  trgConn: "(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=xsbkef2g.adb.eu-paris-1.oraclecloud.com))(connect_data=(service_name=gc2401553d1c7ab_user00_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))"
~~~

## 🚀 Install GoldenGate Pods

Like mentioned at the beginning of this challenge, we will install several components on the AKS cluster under the Namespace "microhacks" via helm. Some of this components will be acccessing via a Web UI, some of them will need to connect to each other. Therefore we need to create some Kubernetes secrets to store the required credentials.

- GoldenGate (ogg-admin-secret)
  - GoldenGate Admin User: ggadmin
- Source Database oracle 23ai free edition
  - Admin User: system (db-admin-secret), ggadmin (srcGGUserName)
- Target Database ODAA ADB
  - Admin User: admin (db-admin-secret), ggadmin (trgGGUserName)

> IMPORTANT: The password for all users must be the same for simplicity and must match the password you defined during the creation of the ODAA ADB instance (should be <"Assigned Password"> (without quotes)).

~~~powershell
# Prompt for the password that will be used for all three components - Please ask if you do not know the one!!!
$password = <REPLACE-WITH-YOUR-ADB-PASSWORD> # e.g., "Welcome1234#"

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

Install all components via Helm:

~~~powershell
helm install ogghack oggfree/goldengate-microhack-sample --values gghack.yaml -n microhacks
~~~

📄 You should see a similar output:

~~~text
NAME: ogghack
LAST DEPLOYED: Wed Nov 12 15:33:39 2025
NAMESPACE: microhacks
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Final NOTES:

Please wait about 2 Minutes for the source database to be completely up and loaded.

You can already try out Your sqlplus command line by using this URL in Your browser:
https://gghack.4.251.147.64.nip.io/sqlplus/vnc.html

Alternatively, have a look at Your personal jupyter notebook:
https://gghack.4.251.147.64.nip.io/jupyter/
Just enter the password "Welcome1234" when asked and then open the CPAT analysis notebook.

Once the DB is ready, GoldenGate Sync should be set up too. Check it out right here:
https://gghack.4.251.147.64.nip.io

...and for GoldenGate for Distributed Applications, check this host name:      
https://daagghack.4.251.147.64.nip.io

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

✅ After the job is completed, the local database, which is running inside the AKS cluster, has been migrated to the ODAA ADB instance via Oracle Data Pump.


### 🔌 Connect to the ADB Oracle Database

~~~powershell
# extract the pod name of the instantcleint as it contains a random suffix
$podInstanteClientName=kubectl get pods -n microhacks | Select-String 'ogghack-goldengate-microhack-sample-instantclient' | ForEach-Object { ($_ -split '\s+')[0] }
# login to the pod instantclient
kubectl exec -it -n microhacks $podInstanteClientName -- /bin/bash
# log into ADB with admin via sqlplus, replace the TNS connection string with your own
sqlplus admin@'(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=t6bchxz9.adb.eu-paris-1.oraclecloud.com))(connect_data=(service_name=gc2401553d1c7ab_user00adb2025111201_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))' # Replace with your TNS connection string
# Enter your password e.g. Welcome1234#
~~~

Inside the sqlplus session, run the following commands to verify the SH2 schema and the GoldenGate GGADMIN user have been created successfully in the ADB instance.

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
SELECT COUNT(*) FROM all_tables WHERE owner = 'SH2';
~~~

~~~text
  COUNT(*)
----------
        18
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
select USERNAME, ACCOUNT_STATUS from DBA_USERS where USERNAME like 'SH2';
~~~

~~~text
USERNAME
--------------------------------------------------------------------------------     
ACCOUNT_STATUS
--------------------------------
SH2
OPEN
~~~

Exit sqlplus

~~~sql
exit
~~~

Exit instantclient pod

~~~bash
exit
~~~


## 💡 Tips and Tricks

### � Troubleshooting Init:ErrImagePull Issues

If you see pods with `Init:ErrImagePull` status, this is likely due to authentication issues with Oracle Container Image Registry (OCIR) or network connectivity problems.

**Common causes:**
1. **Missing Oracle Container Registry authentication**
2. **Network connectivity issues (TLS handshake timeout)**
3. **AKS node storage I/O issues**

### �🔁 Redeploy if things go wrong

~~~powershell
# Update the helm repo 
helm repo update
# login to aks
az aks get-credentials -g $rgAKS -n $AKSClusterName --overwrite-existing
# Uninstall list the available helm charts
helm list -n microhacks 
# Uninstall the Helm release
helm uninstall ogghack -n microhacks
~~~

### Check Network Connectivity**

```powershell
# Test connectivity to Oracle Container Registry from AKS nodes
kubectl run test-connectivity --image=nginx --rm -it --restart=Never -- curl -I https://fra.ocir.io
```

### Restart AKS Nodes (if I/O errors persist)**

```powershell
# If there are persistent I/O errors, restart the AKS nodepool
az aks nodepool update --resource-group $rgAKS --cluster-name $AKSClusterName --name agentpool --enable-cluster-autoscaler
```

### 🔎 Show the logs of the GoldenGate Prepare Job

~~~powershell
# login to aks if not already done
az aks get-credentials -g $rgAKS -n $AKSClusterName --overwrite-existing
# get prep job pod name
$podPrepName = kubectl get pods -n microhacks | Select-String 'ogghack-goldengate-microhack-sample-db-prepare-job' | ForEach-Object { ($_ -split '\s+')[0] }
kubectl logs -n microhacks $podPrepName

# To check for image pull issues:
kubectl describe pod $podPrepName -n microhacks | Select-String -Pattern "Failed|Error|Warning" -A 2 -B 2
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
~~~

### 🔎 Show the logs of the GoldenGate Big Data Container

~~~powershell
# login to aks if not already done
az aks get-credentials -g $rgAKS -n $AKSClusterName --overwrite-existing
# get prep job pod name
$podBigDataName = kubectl get pods -n microhacks | Select-String 'ogghack-goldengate-microhack-sample-daa' | ForEach-Object { ($_ -split '\s+')[0] }
kubectl logs -n microhacks $podBigDataName

# To check for image pull issues:
kubectl describe pod $podBigDataName -n microhacks | Select-String -Pattern "Failed|Error|Warning" -A 2 -B 2

~~~text
~~~




[Back to workspace README](../../README.md)
