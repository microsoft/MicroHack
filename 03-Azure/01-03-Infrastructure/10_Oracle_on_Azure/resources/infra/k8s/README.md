# Kubernetes YAML Files

This directory contains pre-configured Kubernetes YAML files for Oracle ADB performance testing.

## Files Overview

### `namespace.yaml`
Creates the `adb-perf-test` namespace for organizing all performance testing resources.

### `adbping-deployment.yaml` 
Creates a long-running deployment with the adbping container for interactive testing.

### `adbping-job.yaml`
Creates a Kubernetes Job for automated performance testing. 

⚠️ **Important**: Before using `adbping-job.yaml`, you must edit it and replace:
- `YOUR_PASSWORD_HERE` with your actual Oracle ADB password
- `YOUR_TNS_CONNECTION_STRING_HERE` with your actual TNS connection string from your ADB wallet

### `connping-deployment.yaml`
Creates a long-running deployment with the connping container (rwloadsim) for interactive testing.

### `connping-job.yaml`
Creates a Kubernetes Job for automated connping performance testing.

⚠️ **Important**: Before using `connping-job.yaml`, you must edit it and replace:
- `YOUR_PASSWORD_HERE` with your actual Oracle ADB password
- `YOUR_TNS_CONNECTION_STRING_HERE` with your actual TNS connection string from your ADB

## Usage

```powershell
# Deploy all adbping resources (from the project root directory)
kubectl apply -f resources\infra\k8s\namespace.yaml
kubectl apply -f resources\infra\k8s\adbping-deployment.yaml

# For adbping automated testing (after editing the placeholders):
kubectl apply -f resources\infra\k8s\adbping-job.yaml

# Deploy connping resources
kubectl apply -f resources\infra\k8s\connping-deployment.yaml

# For connping automated testing (after editing the placeholders):
kubectl apply -f resources\infra\k8s\connping-job.yaml
```

### Access Interactive Pods

```powershell
# Get adbping pod name and access
$podName = kubectl get pods -n adb-perf-test -l app=adbping -o jsonpath='{.items[0].metadata.name}'
kubectl exec -it $podName -n adb-perf-test -- /bin/bash

# Get connping pod name and access
$podName = kubectl get pods -n adb-perf-test -l app=connping -o jsonpath='{.items[0].metadata.name}'
kubectl exec -it $podName -n adb-perf-test -- /bin/bash
```

## Resource Cleanup

```powershell
# Delete all resources
kubectl delete namespace adb-perf-test
```