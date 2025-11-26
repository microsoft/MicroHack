# 🔄 Challenge 4: OnPrem Ramp Up (Simplified)

[Back to workspace README](../../README.md) | [Original detailed walkthrough](./onprem-ramp-up.md)

> 📖 **This is the simplified version** of Challenge 4. It uses an automated script to deploy everything with minimal manual steps. If you prefer to understand each step in detail, refer to the [original walkthrough](./onprem-ramp-up.md).

---

## 🎯 What You'll Deploy

This challenge sets up Oracle GoldenGate to replicate data from an on-premises Oracle database (running in AKS) to your ODAA Autonomous Database:

| Component | Description |
|-----------|-------------|
| **Oracle Database 23ai Free** | Source database with SH schema (pre-populated) |
| **Oracle Data Pump** | Initial data migration to ODAA ADB |
| **Oracle GoldenGate** | Real-time data replication |
| **Oracle Instant Client** | SQL*Plus access to both databases |

---

## 📋 Prerequisites

Before starting, make sure you have:

- [x] Completed previous challenges (ODAA ADB created)
- [x] Your ODAA ADB password (e.g., `Welcome1234#`)
- [x] Access to your AKS cluster
- [x] Azure CLI, kubectl, and helm installed

---

## 🚀 Step 1: Get Your ODAA Connection String

First, retrieve your ODAA ADB connection string from the Azure Portal:

1. Go to your **ODAA ADB resource** in Azure Portal
2. Navigate to **Connections**
3. Copy the **High** profile connection string

It should look like this:
```
(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=xxx.adb.eu-paris-1.oraclecloud.com))(connect_data=(service_name=xxx_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))
```

> 💡 **Tip**: For detailed instructions, see [How to retrieve the ODAA connection string](../../docs/odaa-get-token.md)

---

## 🚀 Step 2: Run the Deployment Script

Open PowerShell and navigate to this folder, then run:

```powershell
# Navigate to the walkthrough folder
cd walkthrough\onprem-ramp-up

# Login to Azure (if not already logged in)
az login

# Set your AKS subscription (replace with your subscription name)
az account set --subscription "sub-team0"

# Run the deployment script (use $trgConn if you retrieved it via docs\odaa-get-token.md)
.\Deploy-OnPremReplication.ps1 `
    -UserName "user00" `
    -ADBPassword "Welcome1234#" `
    -ADBConnectionString $trgConn
```

### 📝 Script Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-UserName` | Yes | Your assigned username (e.g., `user00`, `user01`) |
| `-ADBPassword` | Yes | Your ODAA ADB password |
| `-ADBConnectionString` | Yes | Full TNS connection string from Step 1 |
| `-AKSResourceGroup` | No | AKS resource group (auto-detected from username) |
| `-AKSClusterName` | No | AKS cluster name (auto-detected from username) |
| `-SkipAKSConnection` | No | Skip if already connected to AKS |
| `-Uninstall` | No | Remove existing deployment first |
| `-TemplateFile` | No | Custom template path (default: `../../resources/template/gghack.yaml`) |

> 💡 **Note**: The script uses the existing `gghack.yaml` template without modifying it. Your user-specific values are applied via Helm `--set` parameters at deployment time.

### ⏳ Wait for Completion

The script will:

1. ✅ Connect to your AKS cluster
2. ✅ Configure Helm repositories
3. ✅ Auto-detect the Ingress external IP
4. ✅ Validate the template file exists
5. ✅ Create Kubernetes secrets
6. ✅ Deploy using template + `--set` overrides (~5-10 minutes)

---

## 🔍 Step 3: Verify the Deployment

Once the script completes, check that all pods are running:

```powershell
kubectl get pods -n microhacks
```

Expected output (after ~8 minutes):
```
NAME                                                              READY   STATUS      RESTARTS   AGE
ogghack-goldengate-microhack-sample-db-xxxxx                      1/1     Running     0          10m
ogghack-goldengate-microhack-sample-db-prepare-job-xxxxx          0/1     Completed   0          10m
ogghack-goldengate-microhack-sample-instantclient-xxxxx           1/1     Running     0          10m
ogghack-goldengate-microhack-sample-jupyter-xxxxx                 1/1     Running     0          10m
ogghack-goldengate-microhack-sample-ogg-xxxxx                     1/1     Running     0          10m
```

> ⚠️ **Note**: Some CrashLoopBackOff errors on the prepare-job are expected while it waits for the database.

---

## 🌐 Step 4: Access the Web Interfaces

The deployment creates several web interfaces (replace `<EXTERNAL-IP>` with your actual IP):

| Interface | URL | Credentials |
|-----------|-----|-------------|
| **GoldenGate UI** | `https://gghack.<EXTERNAL-IP>.nip.io` | ggadmin / your-password |
| **SQLPlus Web** | `https://gghack.<EXTERNAL-IP>.nip.io/sqlplus/vnc.html` | - |
| **Jupyter Notebook** | `https://gghack.<EXTERNAL-IP>.nip.io/jupyter/` | Welcome1234 |
| **GG Big Data** | `https://daagghack.<EXTERNAL-IP>.nip.io` | ggadmin / your-password |

To find your external IP:
```powershell
kubectl get service -n ingress-nginx -o jsonpath='{.items[*].status.loadBalancer.ingress[*].ip}'
```

---

## ✅ Step 5: Verify Data Replication

### Connect to the Instant Client Pod

```powershell
# Get the pod name
$podName = kubectl get pods -n microhacks -o name | Select-String 'instantclient' | ForEach-Object { $_ -replace 'pod/', '' }

# Connect to the pod
kubectl exec -it -n microhacks $podName -- /bin/bash
```

### Verify SH2 Schema in ODAA ADB

From inside the pod:

```bash
# Connect to ODAA ADB (replace with your connection string)
sqlplus admin@'<Replace with the TNS connection string of your deployed ADB>'
# Enter your password when prompted
```

```sql
-- Check that SH2 schema exists
SELECT USERNAME FROM ALL_USERS WHERE USERNAME LIKE 'SH%';

-- Count tables in SH2
SELECT COUNT(*) FROM all_tables WHERE owner = 'SH2';

-- Exit
exit
```

### Test Real-Time Replication

From inside the pod, connect to the on-prem database:

```bash
# Use the pre-configured alias
sql
```

```sql
-- Create a test table
CREATE TABLE SH.SALES_COPY AS SELECT * FROM SH.SALES;

-- Check row count
SELECT COUNT(*) FROM SH.SALES_COPY;

-- Exit
exit
```

Now verify it replicated to ODAA ADB:

```bash
sqlplus admin@'(description= ...your-connection-string...)'
```

```sql
-- Check if table was replicated
SELECT COUNT(*) FROM SH2.SALES_COPY;

-- Exit
exit
```

If you see the same row count, **GoldenGate replication is working!** 🎉

Type `exit` to leave the pod.

---

## 🔧 Troubleshooting

### Redeploy if Something Goes Wrong

```powershell
# Uninstall and reinstall
.\Deploy-OnPremReplication.ps1 `
    -UserName "user00" `
    -ADBPassword "Welcome1234#" `
    -ADBConnectionString "(description= ...)" `
    -Uninstall
```

### Manual Uninstall

```powershell
helm uninstall ogghack -n microhacks
kubectl delete namespace microhacks
```

### Check Pod Logs

```powershell
# Get pod names
kubectl get pods -n microhacks

# Check logs for a specific pod
kubectl logs -n microhacks <pod-name>

# Check the prepare job logs
$prepPod = kubectl get pods -n microhacks -o name | Select-String 'prepare-job' | ForEach-Object { $_ -replace 'pod/', '' }
kubectl logs -n microhacks $prepPod
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Pods stuck in `Init:ErrImagePull` | Network/auth issue with Oracle Container Registry - check logs |
| External IP not assigned | Wait a few minutes, or check ingress-nginx service |
| Connection refused to ADB | Verify connection string and NSG rules |
| Wrong password | Re-run script with `-Uninstall` flag |

---

## ⏭️ Next Challenge

While waiting for the deployment, you can start on:

**[Challenge 5: Measure Network Performance](../perf-test-odaa/perf-test-odaa.md)**

---

## 📚 Additional Resources

- [Original detailed walkthrough](./onprem-ramp-up.md) - Step-by-step manual process
- [ODAA Connection String Guide](../../docs/odaa-get-token.md) - How to get your TNS string
- [Helm Chart Documentation](https://ilfur.github.io/VirtualAnalyticRooms) - GoldenGate Microhack chart

[Back to workspace README](../../README.md)
