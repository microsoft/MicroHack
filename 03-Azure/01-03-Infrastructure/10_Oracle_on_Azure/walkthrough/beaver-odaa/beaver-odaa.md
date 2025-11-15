# 🦫 Challenge 5: Review data replication via Beaver

[Back to workspace README](../../README.md)

🌐 CloudBeaver is a web-based database management tool that allows users to connect to, manage, and query various databases directly from a browser. In the context of Kubernetes, deploying CloudBeaver provides an easy-to-access interface for database administration tasks, such as browsing tables, running SQL queries, and managing database users, without needing to install local database clients. This is especially useful for teams working in cloud or containerized environments.

~~~powershell
# switch to the subscription where AKS is deployed
$subAKS="sub-mh1" # replace with your AKS subscription name
# Make sure your cli points to the AKS subscription
az account set --subscription $subAKS
# log in your AKS cluster if not already done
$rgAKS="aks-user01" # replace with your AKS resource group name
$AKSClusterName="aks-user01" # replace with your AKS cluster name
az aks get-credentials -g $rgAKS -n $AKSClusterName --overwrite-existing

# Deploy Cloud Beaver
helm repo add avisto https://avistotelecom.github.io/charts/
kubectl create namespace cloudbeaver
helm install cloudbeaver avisto/cloudbeaver --version 1.0.1 -n cloudbeaver

# get the external IP of the ingress controller and strip spaces
$EXTIP = (kubectl get service -n ingress-nginx -o jsonpath='{range .items[*]}{.status.loadBalancer.ingress[*].ip} {end}') -replace '\s', ''

echo "
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cloudbeaver-ingress
  namespace: cloudbeaver
spec:
  ingressClassName: nginx
  rules:
  - host: beaver.$EXTIP.nip.io
    http:
      paths:
      - backend:
          service:
            name: cloudbeaver
            port:
              number: 8978
        path: /
        pathType: Prefix
" | kubectl apply -f -

# get the hostname of the beaver ingress
echo "You can access beaver under: https://beaver.${EXTIP}.nip.io"

# validate access to beaver
http GET https://beaver.${EXTIP}.nip.io --verbose
~~~

## 🔗 Create Connection to the AKS local Oracle Database

> ⚠️ **IMPORTANT**: In case you are using an Azure Network Security Group (NSG) make sure your client IP is whitelisted to access the AKS where Beaver is running.

1. 🌐 Go to CloudBeaver and set the Password as follows:
    - 👤 User: cbadmin
    - 🔐 Password: <"Assigned Password"> (replace by your password)
    - Click the "Next" button on top of the page and "Finish" button afterwards.
2. 🔑 Login to CloudBeaver after you did set the password.
3. ☁️ Select the cloud icon on the upper left corner.
4. ➕ Select "New Connection"
5. 🔶 Select Oracle
6. ⚙️ Select Configuration option "URL" instead of "Manual"
7. 🔗 Enter the following JDBC URL: jdbc:oracle:thin:@ogghack-goldengate-microhack-sample-db23ai.microhacks:1521/freepdb1
8. 👤 Set User name = system
9. 🔐 Set Password = <"Assigned Password">
10. 💾 Select check box "Save credentials for all users with access"
11. 🧪 Select "Test"
12. ✅ You should see "Success" popup
13. 🎯 Select "Create" on the upper right corner

## 🔗 Create Connection to the ODAA ADB (work in progress)

1. ➕ Select the "New connection" Icon on the upper left corner.
2. 🔶 Select Oracle
3. ⚙️ Select Configuration option "URL" instead of "Manual"
4. 🔧 Construct an easy connect string with your current connection string and the needed prefixes similar to the following one: jdbc:oracle:thin:@(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=gpdmotes.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_odaa2_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))
5. Set "Connection name" to "adb"
6. 👤 Set User name = admin
7. 🔐 Set Password = <"Assigned Passwort">
8. 💾 Select check box "Save credentials for all users with access"
9. 🧪 Select "Test Connection"
10. ✅ You should see "Success" popup
11. 🎯 Select "Create" on the upper right corner


## 💡 Tips and Tricks

### 🔁 Redeploy if things go wrong

~~~powershell
# login to aks
az aks get-credentials -g $rgAKS -n $AKSClusterName --overwrite-existing
# Uninstall the Helm release
helm uninstall cloudbeaver -n cloudbeaver
~~~

[Back to workspace README](../../README.md)