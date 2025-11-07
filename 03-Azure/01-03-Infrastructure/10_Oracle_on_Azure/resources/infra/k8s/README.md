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

## Usage

```powershell
# Deploy all resources (from the project root directory)
kubectl apply -f resources\infra\k8s\namespace.yaml
kubectl apply -f resources\infra\k8s\adbping-deployment.yaml

# For automated testing (after editing the placeholders):
kubectl apply -f resources\infra\k8s\adbping-job.yaml
```

## Resource Cleanup

```powershell
# Delete all resources
kubectl delete namespace adb-perf-test
```