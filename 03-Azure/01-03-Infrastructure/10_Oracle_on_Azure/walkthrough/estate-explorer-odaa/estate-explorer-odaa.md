# 📊 Challenge 7: (Optional) Use Estate Explorer to visualize the Oracle ADB instance

[Back to workspace README](../../README.md)

## 🎯 Overview

Estate Explorer provides comprehensive visualization and analysis capabilities for Oracle databases, helping you understand your database landscape and performance characteristics.

## 🚀 Installation Steps

~~~bash
# 📦 Installation estate explorer

helm show values oggfree/autonomous-free >autonomous.yaml
# 🌐 getting public address of nginx ingress controller
export EXTIP=$(kubectl get service -n ingress-nginx -o jsonpath='{range .items[*]} {.status.loadBalancer.ingress[*].ip} {end}')
# 🔧 putting the external address into the deployment
sed -i "s/xxx-xxx-xxx-xxx/${EXTIP// /}/g" autonomous.yaml

# ⚠️ BEFORE running the install, please exchange the database password in autonomous.yaml !
kubectl create namespace estateexplorer
helm install estate-exp oggfree/autonomous-free --values autonomous.yaml -n estateexplorer
~~~

## 📋 Post-Installation

1. ⏳ Wait for all pods to be in running state
2. 🌐 Access the Estate Explorer interface via the configured ingress
3. 🔗 Configure connection to your Oracle ADB instance
4. 📊 Explore the visualization capabilities

[Back to workspace README](../../README.md)
