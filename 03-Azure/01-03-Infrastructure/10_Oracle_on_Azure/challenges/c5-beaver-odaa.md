# 🦫 Challenge 5: Review data replication via Beaver

🌐 CloudBeaver is a web-based database management tool that allows users to connect to, manage, and query various databases directly from a browser. In the context of Kubernetes, deploying CloudBeaver provides an easy-to-access interface for database administration tasks, such as browsing tables, running SQL queries, and managing database users, without needing to install local database clients. This is especially useful for teams working in cloud or containerized environments.

~~~bash
# Deployment Cloud Beaver
helm repo add avisto https://avistotelecom.github.io/charts/
kubectl create namespace cloudbeaver
helm install cloudbeaver avisto/cloudbeaver --version 1.0.1 -n cloudbeaver

export EXTIP=$(kubectl get service -n ingress-nginx -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}")

echo "
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cloudbeaver-ingress
  namespace: cloudbeaver
spec:
  ingressClassName: nginx
  rules:
  - host: beaver.${EXTIP}.nip.io
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

# get the hostname of the beavor ingress
echo "You can access beaver under: http://beaver.${EXTIP}.nip.io"
~~~

## 🔗 Create Connection to the AKS local Oracle Database

> ⚠️ **IMPORTANT**: In case you are using an Azure Network Security Group (NSG) make sure your client IP is whitelisted to access the AKS where Beaver is running.

1. 🌐 Go to Beaver and set the Password as follows:
    - 👤 User: cbadmin
    - 🔐 Password: Welcome1234#
2. 🔑 Login to Beaver after you did set the password.
3. ☁️ Select the Cloud Icon on the upper left corner.
4. ➕ Select "New Connection"
5. 🔶 Select Oracle
6. ⚙️ Select Configuration=URL
7. 🔗 Enter the following JDBC URL: jdbc:oracle:thin:@ogghack-goldengate-microhack-sample-db23ai.microhacks:1521/freepdb1
8. 👤 Set User name = system
9. 🔐 Set Password = Welcome1234#
10. 💾 Select check box "Save credentials for all users with access"
11. 🧪 Select "Test Connection"
12. ✅ You should see "Success" popup
13. 🎯 Select "Create" on the upper right corner

## 🔗 Create Connection to the ODAA ADB (work in progress)

1. 🌐 Go to Beaver and set the Password as follows:
    - 👤 User: cbadmin
    - 🔐 Password: Welcome1234#
2. 🔑 Login to Beaver after you did set the password.
3. ☁️ Select the Cloud Icon on the upper left corner.
4. ➕ Select "New Connection"
5. 🔶 Select Oracle
6. ⚙️ Select Configuration=URL
7. 🔧 Compile an easy connect string with your current connection string and the needed prefixes similar to the following one: "jdbc:oracle:thin:@"(description=(retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=xxxxxxxxxxxxxxxx.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=xxxxxxxxxxxxxxxxxxx_adbger_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))"
8. 👤 Set User name = admin
9. 🔐 Set Password = Welcome1234#
10. 💾 Select check box "Save credentials for all users with access"
11. 🧪 Select "Test Connection"
12. ✅ You should see "Success" popup
13. 🎯 Select "Create" on the upper right corner
