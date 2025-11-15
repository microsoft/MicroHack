# Oracle ADB Connping Testing Container

Connection and latency test tool for Oracle Autonomous Database using **rwloadsim** (connping/ociping) created by Oracle's Real World Performance team.

## Overview

This container provides the rwloadsim tool suite for testing Oracle ADB connection latency. The primary metric to monitor is **ociping**, which measures the connection latency to your Oracle Autonomous Database.

**Based on:** [rwloadsim GitHub Repository](https://github.com/oracle/rwloadsim)  
**Version:** 3.2.1

## Features

✅ **Pre-installed rwloadsim**: Complete tool suite including connping and ociping  
✅ **Oracle Instant Client 23c**: Latest Oracle client with SQL*Plus  
✅ **Network testing tools**: dig, ping, traceroute, nc, curl, wget  
✅ **Security**: Runs as non-root user  
✅ **Kubernetes ready**: Pre-configured for AKS deployment  
✅ **ACR integrated**: Built for `odaamh.azurecr.io` registry

## Essential Files

- **`Dockerfile`** - Production Docker build with Oracle Client 23c and rwloadsim
- **`entrypoint.sh`** - Container entrypoint script with help and diagnostics
- **`build.sh`** - Build script for local Docker Desktop and ACR push

## Quick Build & Test

### Prerequisites

- Docker Desktop installed and running
- Azure CLI installed
- Access to `odaamh` Azure Container Registry

### Build Locally

```bash
# Navigate to the connping directory
cd resources/infra/connping

# Make the build script executable (Linux/Mac) or run in Git Bash (Windows)
chmod +x build.sh entrypoint.sh
./build.sh

# Or build manually
docker build -t connping:v1.0 .
```

### Test Locally

```bash
# Test connping is available
docker run --rm connping:v1.0 connping --help

# Test with interactive shell
docker run --rm -it connping:v1.0 bash
```

## Push to Azure Container Registry

```bash
# Login to Azure and ACR
az login
az account set --subscription 09808f31-065f-4231-914d-776c2d6bbe34
az acr login --name odaamh

# Push the image
docker push odaamh.azurecr.io/connping:v1.0
docker push odaamh.azurecr.io/connping:latest

# Verify
az acr repository show --name odaamh --image connping:v1.0
```

## Production Usage

### Basic Latency Test (One-way TLS)

```bash
docker run --rm odaamh.azurecr.io/connping:v1.0 \
  connping -l 'admin/YourPassword@"(description= (retry_count=20)(retry_delay=3)\
    (address=(protocol=tcps)(port=1521)(host=adb.eu-frankfurt-1.oraclecloud.com))\
    (connect_data=(service_name=mydb_tp.adb.oraclecloud.com))\
    (security=(ssl_server_dn_match=yes)))"' \
  --period=300
```

### Latency Test with Wallet

```bash
docker run --rm \
  -v $(pwd)/wallet:/opt/oracle/wallet \
  odaamh.azurecr.io/connping:v1.0 \
  connping -l admin/password@mydb_high --period=300
```

### Network Diagnostics

```bash
# DNS lookup
docker run --rm odaamh.azurecr.io/connping:v1.0 \
  dig adb.eu-frankfurt-1.oraclecloud.com

# Ping test
docker run --rm odaamh.azurecr.io/connping:v1.0 \
  ping -c 10 adb.eu-frankfurt-1.oraclecloud.com

# Interactive troubleshooting
docker run --rm -it odaamh.azurecr.io/connping:v1.0 bash
```

## Kubernetes Deployment

Deploy to AKS using the pre-configured YAML files:

```powershell
# Deploy namespace (if not already created)
kubectl apply -f ..\k8s\namespace.yaml

# Deploy connping pod
kubectl apply -f ..\k8s\connping-deployment.yaml

# For automated testing
kubectl apply -f ..\k8s\connping-job.yaml
```

### Access the Pod

```powershell
# Get pod name
$podName = kubectl get pods -n adb-perf-test -l app=connping -o jsonpath='{.items[0].metadata.name}'

# Execute interactive shell
kubectl exec -it $podName -n adb-perf-test -- /bin/bash

# Run connping test
kubectl exec -it $podName -n adb-perf-test -- connping -l "admin/pass@..." --period=300
```

## Understanding connping Output

When you run connping, watch for the **ociping** metric:

```
ociping: 2.45ms    <- This is the key metric to monitor
```

This represents the connection latency to your Oracle ADB instance.

### Sample Output

```
RWL*Load Simulator Release 3.2.1.0 Production
...
ociping: 2.45ms
sqlping: 3.21ms
total connections: 1234
successful: 1234
failed: 0
```

## Tool Details

### connping Command

```bash
connping -l <connection_string> [options]

Options:
  -l          Connection string (user/pass@tns or full TNS descriptor)
  --period    Duration in seconds to run the test (default: 60)
```

### Environment Variables

- `TNS_ADMIN` - Oracle wallet location (default: `/opt/oracle/wallet`)
- `ORACLE_HOME` - Oracle client home (default: `/usr/lib/oracle/23/client64`)
- `LD_LIBRARY_PATH` - Oracle library path

## Setup Requirements for connping

As per the original specifications:

1. **VM/Container**: System that can connect to ADB with sqlplus installed ✅
2. **rwloadsim Tool**: Downloaded from GitHub releases ✅
3. **Environment Setup**: 
   - PATH includes rwloadsim bin directory ✅
   - LD_LIBRARY_PATH includes Oracle Client 23c ✅

## Comparison with adbping

| Feature | adbping | connping (rwloadsim) |
|---------|---------|----------------------|
| **Source** | Oracle Support (MOS) | Oracle Real World Performance Team |
| **Tool Type** | Standalone binary | Part of rwloadsim suite |
| **Primary Metric** | Connection + SQL time | ociping (connection latency) |
| **Client Support** | Java, SQL*Plus | SQL*Plus based |
| **Oracle Client** | 21c | 23c |

## Troubleshooting

### Connection Issues

```bash
# Test DNS resolution
docker run --rm odaamh.azurecr.io/connping:v1.0 \
  dig adb.eu-frankfurt-1.oraclecloud.com

# Test network connectivity
docker run --rm odaamh.azurecr.io/connping:v1.0 \
  ping -c 4 adb.eu-frankfurt-1.oraclecloud.com
```

### Wallet Issues

```bash
# Verify wallet is mounted correctly
docker run --rm -v $(pwd)/wallet:/opt/oracle/wallet \
  odaamh.azurecr.io/connping:v1.0 \
  ls -la /opt/oracle/wallet
```

## Notes

- This is the production version with Oracle Instant Client 23c
- The rwloadsim tool is pre-installed and ready to use
- For Kubernetes deployment, use the YAML files in `resources/infra/k8s/`
- The container runs as a non-root user for security
- One-way TLS connections do not require a wallet mount

## Reference Documentation

- **rwloadsim GitHub**: https://github.com/oracle/rwloadsim
- **Release v3.2.1**: https://github.com/oracle/rwloadsim/releases/tag/v.3.2.1
- **Oracle Real World Performance**: Oracle's performance engineering team

## About rwloadsim

The RWP*Load Simulator (rwloadsim) is a tool created by Oracle's Real World Performance team for simulating real-world workloads. The connping/ociping utilities within this suite provide accurate connection latency measurements to Oracle databases.
