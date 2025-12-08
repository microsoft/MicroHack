# 🔌 Challenge 5: Performance Testing (Simplified)

[Back to workspace README](../../README.md) | [Original detailed walkthrough](./perf-test-odaa.md)

> 📖 We are going to use an automated script to run performance tests against your ODAA Autonomous Database with minimal manual steps.

---

## 🎯 What You'll Test

This challenge measures the network performance between your AKS cluster and ODAA Autonomous Database:

| Metric | Description | Good Value |
|--------|-------------|------------|
| **ociping** | Database round-trip latency | < 2ms |
| **SQL Execution Time** | Time to execute `SELECT 1 FROM DUAL` | < 1ms |
| **Connect Time** | Session establishment time | < 150ms |
| **P95/P99 Latency** | 95th/99th percentile latencies | < 2ms |

---

## 📋 Prerequisites

Before starting, make sure you have:

- [x] Completed previous challenges (ODAA ADB created)
- [x] Your ODAA ADB password
- [x] Access to your AKS cluster
- [x] Azure CLI and kubectl installed
- [x] The `adb-perf-test` namespace deployed (from Challenge 2)

---

## 🚀 Step 1: Get Your ODAA Connection String

First, retrieve your ODAA ADB connection string:

```powershell
# Set your variables
$adbName = "user00"           # Replace with your ADB name
$rgODAA = "odaa-user00"       # Replace with your ODAA resource group
$subODAA = "sub-mhodaa"       # Replace with your ODAA subscription

# Switch to ODAA subscription
az account set --subscription $subODAA

# Get the TNS connection string
$trgConn = az oracle-database autonomous-database show `
    -g $rgODAA -n $adbName `
    --query "connectionStrings.profiles[?consumerGroup=='High' && protocol=='TCPS' && tlsAuthentication=='Server'].value | [0]" `
    -o tsv

echo $trgConn
```

> 💡 **Tip**: For detailed instructions, see [How to retrieve the ODAA connection string](../../docs/odaa-get-token.md)

---

## 🚀 Step 2: Run the Performance Test Script

Open PowerShell and navigate to this folder, then run:

```powershell
# Navigate to the walkthrough folder
cd walkthrough\perf-test-odaa

# Set your AKS subscription
az account set --subscription "sub-team0"  # Replace with your AKS subscription

# Run the performance test script
.\Deploy-PerfTest.ps1 `
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
| `-TestType` | No | `adbping`, `connping`, or `both` (default: `adbping`) |
| `-TestDuration` | No | Test duration in seconds (default: 90) |
| `-Threads` | No | Number of concurrent threads for adbping (default: 3) |
| `-AKSResourceGroup` | No | AKS resource group (auto-detected from username) |
| `-AKSClusterName` | No | AKS cluster name (auto-detected from username) |
| `-SkipAKSConnection` | No | Skip if already connected to AKS |
| `-Cleanup` | No | Remove test jobs after completion |

### ⏳ Wait for Results

The script will:

1. ✅ Connect to your AKS cluster
2. ✅ Set up the test namespace
3. ✅ Deploy the performance test job
4. ✅ Wait for completion (~2-3 minutes)
5. ✅ Display the results

---

## 📊 Step 3: Understanding the Results

### ADBPing Results

```text
+++Test Summary+++
   Test Client: java
   Number of concurrent threads: 3
   Duration (secs): 90
   SQL executed: select 1 from dual;
   Pass: 341760 Fail: 0
   SQL Execution Time(ms) : Min:0.543 Max:89.571 Avg:0.747 Median:0.653 Perc90:0.762 Perc95:0.778 Perc99:0.891
   Connect + SQL Execution Time(ms) : Min:0.549 Max:89.797 Avg:0.76 Median:0.661 Perc90:0.77 Perc95:0.791 Perc99:0.968
```

### ConnPing Results

```text
connect mean=111.78, stddev=6.27, min=104.73, max=139.55
ociping mean=0.95, stddev=0.08, min=0.80, max=1.25
dualping mean=1.00, stddev=0.09, min=0.85, max=1.23
```

### Performance Benchmarks

| Metric | Excellent | Good | Needs Investigation |
|--------|-----------|------|---------------------|
| **ociping/SQL Execution** | < 1ms | 1-2ms | > 5ms |
| **Connect Time** | < 120ms | 120-200ms | > 300ms |
| **P99 Latency** | < 2ms | 2-5ms | > 10ms |
| **Pass Rate** | 100% | > 99% | < 99% |

---

## 🔧 Running Both Test Types

To run both adbping and connping tests:

```powershell
.\Deploy-PerfTest.ps1 `
    -UserName "user00" `
    -ADBPassword "Welcome1234#" `
    -ADBConnectionString $trgConn `
    -TestType "both"
```

---

## 🔧 Troubleshooting

### Check Test Job Status

```powershell
# View running jobs
kubectl get jobs -n adb-perf-test

# Check pod status
kubectl get pods -n adb-perf-test

# View logs for a specific job
kubectl logs job/adbping-performance-test -n adb-perf-test
```

### Rerun Tests

```powershell
# Clean up and rerun
.\Deploy-PerfTest.ps1 `
    -UserName "user00" `
    -ADBPassword "Welcome1234#" `
    -ADBConnectionString $trgConn `
    -Cleanup

# Then run again
.\Deploy-PerfTest.ps1 `
    -UserName "user00" `
    -ADBPassword "Welcome1234#" `
    -ADBConnectionString $trgConn
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Job stuck in `Pending` | Check if `adb-perf-test` namespace has the required pods |
| Connection timeout | Verify TNS connection string and NSG rules |
| High latency (> 10ms) | Check network path, VNet peering, or DNS resolution |
| Jobs not found | Ensure the perf-test pods are deployed from Challenge 2 |

---

## 📈 Advanced: Interactive Testing

For more control, you can run tests interactively:

```powershell
# Get the adbping pod name
$podName = kubectl get pods -n adb-perf-test -l app=adbping -o jsonpath="{.items[0].metadata.name}"

# Run custom adbping test
kubectl exec -it $podName -n adb-perf-test -- adbping `
    -u "admin" `
    -p "Welcome1234#" `
    -o `
    -l "(description= ...your-connection-string...)" `
    -c java -t 5 -d 60
```

---

## ⏭️ Next Steps

You've completed Challenge 5! Here's what to explore next:

- **Compare results** across different times of day
- **Test with different thread counts** to measure scalability
- **Review NSG rules** if latency is higher than expected

---

## 📚 Additional Resources

- [Original detailed walkthrough](./perf-test-odaa.md) - Manual testing process
- [ODAA Connection String Guide](../../docs/odaa-get-token.md) - How to get your TNS string
- [ADBPing Documentation](https://github.com/oracle/adbping) - Oracle's performance testing tool

[Back to workspace README](../../README.md)
