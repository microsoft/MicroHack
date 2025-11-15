# Deploy Oracle ADB Ping Pod

## Prerequisites

- AKS cluster with access to Oracle Container Registry
- Oracle Container Registry credentials (if using private images)
- ODAA Autonomous Database connection details

## Step 1: Create Oracle Container Registry Secret (if needed)

```powershell
kubectl create secret docker-registry ocir-secret -n microhacks `
  --docker-server=container-registry.oracle.com `
  --docker-username='<oracle-username>' `
  --docker-password='<oracle-auth-token>' `
  --docker-email='<your-email>'
```

## Step 2: Deploy the Pod

```powershell
kubectl apply -f resources/pods/oracle-adbping.yaml
```

Wait for the pod to be ready:

```powershell
kubectl wait pod/oracle-adbping -n microhacks --for=condition=Ready --timeout=120s
```

## Step 3: Copy the adbping Script to the Pod

```powershell
kubectl cp resources/scripts/adbping.sh microhacks/oracle-adbping:/home/oracle/adbping.sh
kubectl exec -n microhacks oracle-adbping -- chmod +x /home/oracle/adbping.sh
```

## Step 4: Run the ADB Ping Test

```powershell
# Set your connection details
$ADB_HOST = "zeii0mxy.adb.eu-paris-1.oraclecloud.com"
$ADB_SERVICE = "gc2401553d1c7ab_adbuser01_high.adb.oraclecloud.com"
$ADB_USER = "admin"
$ADB_PASSWORD = Read-Host -Prompt "Enter the shared password"

# Build connection string
$CONNECTION_STRING = "(description=(retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=$ADB_HOST))(connect_data=(service_name=$ADB_SERVICE))(security=(ssl_server_dn_match=no)))"

# Execute the ping test
kubectl exec -n microhacks oracle-adbping -- /home/oracle/adbping.sh "$CONNECTION_STRING" "$ADB_USER" "$ADB_PASSWORD" 10
```

## Step 5: Interactive Shell (Optional)

For manual testing:

```powershell
kubectl exec -it -n microhacks oracle-adbping -- /bin/bash

# Inside the pod:
export TNS_CONN="(description=(retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=zeii0mxy.adb.eu-paris-1.oraclecloud.com))(connect_data=(service_name=gc2401553d1c7ab_adbuser01_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))"

# Test with tnsping
tnsping "$TNS_CONN"

# Test with sqlplus
sqlplus admin/<"Assigned Password">#@"$TNS_CONN"
```

## Cleanup

```powershell
kubectl delete pod oracle-adbping -n microhacks
```

## Troubleshooting

### Image Pull Issues

If the pod fails to pull the image:

1. Check the image pull secret:
   ```powershell
   kubectl get secret ocir-secret -n microhacks
   ```

2. Use an alternative public image:
   ```yaml
   image: ghcr.io/gvenzl/oracle-instantclient:21
   # Remove imagePullSecrets section
   ```

### Connection Failures

1. Verify DNS resolution:
   ```powershell
   kubectl exec -n microhacks oracle-adbping -- nslookup zeii0mxy.adb.eu-paris-1.oraclecloud.com
   ```

2. Check network connectivity:
   ```powershell
   kubectl exec -n microhacks oracle-adbping -- openssl s_client -connect zeii0mxy.adb.eu-paris-1.oraclecloud.com:1521 -brief
   ```

3. Review NSG rules and VNet peering between AKS and ODAA subnets
