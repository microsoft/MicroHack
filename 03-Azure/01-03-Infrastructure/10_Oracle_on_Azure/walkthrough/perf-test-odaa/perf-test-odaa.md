# 🔌 Challenge 3: Perform Connectivity Tests on Oracle Database@azure [ODAA] Autonoumous Database

[Back to workspace README](../../README.md)

ODAA Autonoumous Database are so called PaaS (Platform as a Service) offerings, where the underlying infrastructure is fully managed by Microsoft and Oracle.

Installing tools like iperf, sockperf, etc is not possible on the ODAA ADB instance itself, as you would do it on a VM or Bare Metal server.

The following exercise will use the oracle instant client running inside the AKS cluster to connect via sqlplus to the ODAA Autonomous Database instance, and perform some simple latency measurements via SQL queries.

The SQL queries will measure the network round trips, elapsed time, DB time, and calculate the latency per round trip.

This is inspired from the blog of Clemens Bleile.

## 🔐 Login to Azure and set the right subscription

~~~bash
az login --use-device-code
# switch to the subscription where AKS is deployed

$subAKS="sub-mh1" # replace with your AKS subscription name

# Make sure your cli points to the AKS subscription
az account set --subscription $subAKS
~~~

## 🌍 Define required environment variables

~~~bash
# log into your AKS cluster if not already done

$rgAKS="rg-aks-user01" # replace with your AKS resource group name

$AKSClusterName="aks-user01" # replace with your AKS cluster name
~~~

## ⚓ Connect to AKS

~~~bash
# login to aks
az aks get-credentials -g $rgAKS -n $AKSClusterName --overwrite-existing
~~~

### 📡 SQL Ping Test from AKS to ODAA ADB

Reference the document [How to retrieve the Oracle Database Autonomous Database connection string from ODAA](../../docs/odaa-get-token.md) to get the TNS connection string for your ODAA ADB instance.

⚠️ **Important**: If you follow the instructions in `docs\odaa-get-token.md`, remember to switch back to your AKS subscription after retrieving the TNS connection string:

~~~powershell
# Switch back to AKS subscription after getting TNS connection string
az account set --subscription $subAKS
~~~

The script consist of two parts, Setup and Test.

Just run once the Setup part, then the Test part - can be repeated as much as desired, actually it’s good to logout of sqlplus and login again and run it a few times.

~~~powershell
# extract the pod name of the instantcleint as it contains a random suffix
$podInstanteClientName=kubectl get pods -n microhacks | Select-String 'ogghack-goldengate-microhack-sample-instantclient' | ForEach-Object { ($_ -split '\s+')[0] }
# login to the pod InstanteClientName
kubectl exec -it -n microhacks $podInstanteClientName -- /bin/bash
~~~

Inside the instantclient pod, run the following commands:

~~~bash
# Example DIY quick test script (bash + sqlplus): 

sqlplus admin@'(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=xsbkef2g.adb.eu-paris-1.oraclecloud.com))(connect_data=(service_name=gc2401553d1c7ab_user00_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))' # replace with your TNS connection string
# Enter your password e.g. Welcome1234#
~~~

Execute the Setup

~~~sql
-- Setup
drop table tlat purge;
create table tlat (id number, filler varchar2(200));
exec dbms_random.seed(0);
insert into tlat select rownum,dbms_random.string('L',dbms_random.value(100,100)) from all_objects where rownum <= 5000;
commit;
exec dbms_stats.gather_table_stats(user,'TLAT');
create or replace function net_roundtrips return number as
nrt number;
begin
   select mystat.value into nrt
   from v$mystat mystat, v$statname statname
   where mystat.statistic# = statname.statistic#
   and statname.display_name = 'SQL*Net roundtrips to/from client';
   return nrt;
end;
/
~~~

Create function my_db_time_microsecs return number as

~~~sql
create or replace function my_db_time_microsecs return number as
mydbtime number;
begin
   select value into mydbtime
   from V$SESS_TIME_MODEL
   where sid=SYS_CONTEXT( 'USERENV', 'SID' )
   and stat_name='DB time';
   return mydbtime;
end;
/
~~~

~~~sql
-- Test
set echo on
var roundtrips_begin number;
var roundtrips_end number;
var time_begin number;
var time_end number;
var db_time_start number;
var db_time_end number;
set feed only arraysize 15
-- set arraysize 5000
-- set rowprefetch 32000
set arraysize 1
begin
   :roundtrips_begin := NET_ROUNDTRIPS;
   :db_time_start := MY_DB_TIME_MICROSECS;
   :time_begin := dbms_utility.get_time;
end;
/
~~~

~~~sql
select filler from tlat;
begin
   :roundtrips_end := NET_ROUNDTRIPS;
   :db_time_end := MY_DB_TIME_MICROSECS;
   :time_end := dbms_utility.get_time;
end;
/
set serveroutput on feed off
exec dbms_output.put_line(to_char(:roundtrips_end - :roundtrips_begin)||' network round trips.');
exec dbms_output.put_line(to_char((:time_end - :time_begin)*10)||' ms elapsed time.');
exec dbms_output.put_line(to_char((:db_time_end - :db_time_start)/1000)||' ms DB time.');
exec dbms_output.put_line(to_char(round((((:time_end - :time_begin)*10)-((:db_time_end - :db_time_start)/1000))/(:roundtrips_end - :roundtrips_begin),3))||' ms latency per round trip.');
exec dbms_output.put_line('--> (Elapsed Time - DB Time) / network round trips');
set echo off
~~~

~~~text
5000 rows selected.

SQL>   2    3    4    5    6
PL/SQL procedure successfully completed.

SQL> SQL> 1669 network round trips.
SQL> 15160 ms elapsed time.
SQL> 58.106 ms DB time.
SQL> 9.048 ms latency per round trip.
SQL> --> (Elapsed Time - DB Time) / network round trips
~~~

> NOTE: There is as an alternative but with a bit more work to setup - the OCIPING/CONNPING tool created by Oracle’s Real World Performance team (actually part of a larger tool called rwloadsim):

### 📶 Test TCP Connection Time to ADB without sqlplus

The following method can be used to measure the TCP connection time from within the AKS cluster to the ADB instance.
It does establish a new TCP connection 10 times in a row and measures the time taken for each connection attempt.
This for sure include the TCP handshake time everytime and therefore the results will not be that accurate compared to the method described above.

~~~bash
# Test tcp connection time to ADB
bash -c 'H=fxdivzxo.adb.eu-paris-1.oraclecloud.com;P=1521;for i in {1..10};do t0=$(date +%s%3N);(echo >/dev/tcp/$H/$P) &>/dev/null && dt=$(( $(date +%s%3N)-t0 )) || dt=-1;echo "$i: ${dt} ms";sleep 1;done' # replace with your ADB host
~~~

~~~text
1: 13 ms
2: 19 ms
3: 18 ms
4: 27 ms
5: 13 ms
6: 10 ms
7: 11 ms
8: 13 ms
9: 17 ms
10: 16 ms
~~~

## 🚀 Performance Testing with ADBPing Tool from Azure Container Registry

The following section demonstrates how to connect to AKS, deploy a performance testing container from Azure Container Registry, and run comprehensive Oracle ADB performance tests using the `adbping` tool.

### 🔑 Step 1: Azure Authentication and Subscription Setup

First, ensure you're authenticated and set to the correct subscriptions:

~~~powershell
# Login to Azure if not already authenticated
az login --use-device-code

# Set subscription for AKS cluster
$subAKS="sub-mh1" # replace with your AKS subscription name
az account set --subscription $subAKS

# Verify current subscription
az account show --output table
~~~

### 🔐 Step 2: Connect to AKS Cluster

~~~powershell
# Get AKS credentials and configure kubectl
az aks get-credentials --resource-group $rgAKS --name $AKSClusterName --overwrite-existing

# Verify connection to cluster
kubectl get nodes
kubectl get namespaces
~~~

### 🏗️ Step 3: Deploy ADBPing Container

Create a Kubernetes deployment for the adbping performance testing tool using external YAML files:

~~~powershell
# Deploy namespace and ADBPing container using external YAML files
kubectl apply -f resources\infra\k8s\namespace.yaml,resources\infra\k8s\adbping-deployment.yaml

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=adbping -n adb-perf-test --timeout=300s

# Get pod name for interactive access
$podName = kubectl get pods -n adb-perf-test -l app=adbping -o jsonpath="{.items[0].metadata.name}"
Write-Host "Pod Name: $podName"
~~~

### ⚡ Step 4: Configure and Run Performance Tests

Execute comprehensive performance tests using the adbping tool. The recommended approach is using a Kubernetes Job for automated, repeatable testing.

#### Option A: Automated Job-based Testing (Recommended)

**Advantages**: Repeatable, automated, captures complete output, no manual intervention required.

Create a customized performance testing job with your actual ADB credentials:

**Prerequisites**: Ensure you have obtained the TNS connection string by following [docs\odaa-get-token.md](../../docs/odaa-get-token.md) and assigned it to the `$trgConn` variable.

~~~powershell
# Create a copy of the job template to avoid overwriting the original
Copy-Item "resources\infra\k8s\adbping-job.yaml" "adbping-job-custom.yaml"

# Configure your ADB connection details

$ADB_PASSWORD = "Welcome1234#"  # Replace with your actual ADB password
$ADB_TNS = $trgConn  # Use the TNS connection string obtained from docs\odaa-get-token.md

# Update the job configuration with your credentials
(Get-Content adbping-job-custom.yaml) -replace 'YOUR_PASSWORD_HERE', $ADB_PASSWORD | Set-Content adbping-job-custom.yaml
(Get-Content adbping-job-custom.yaml) -replace 'YOUR_TNS_CONNECTION_STRING_HERE', $ADB_TNS | Set-Content adbping-job-custom.yaml

# Verify the changes - show the updated configuration lines
Write-Host "📋 Updated job configuration:" -ForegroundColor Green
(Get-Content adbping-job-custom.yaml)[23..26] | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
~~~

The updated configuration should look like this:

~~~yaml
          USER="admin"
          PASSWORD="Welcome1234#"  # Your actual password
          TNS="(description= (retry_count=20)(retry_delay=3)...)"  # Your actual TNS string
~~~

Deploy and monitor the performance testing job:

~~~powershell
# Deploy the customized performance testing job
kubectl apply -f adbping-job-custom.yaml

# Monitor the job progress
kubectl get jobs -n adb-perf-test

# Wait for job to complete and view results
kubectl wait --for=condition=complete job/adbping-performance-test -n adb-perf-test --timeout=300s

# View test results
kubectl logs job/adbping-performance-test -n adb-perf-test

# Alternative: View logs by label (if needed)
kubectl logs -l job-name=adbping-performance-test -n adb-perf-test

# Check job status and details
kubectl describe job adbping-performance-test -n adb-perf-test

# If job fails, check pod logs for troubleshooting
kubectl get pods -n adb-perf-test
kubectl logs <pod-name> -n adb-perf-test  # Replace <pod-name> with actual pod name
~~~

#### Option B: Interactive Testing (Advanced)

For interactive testing and custom test scenarios:

~~~powershell
# Enter the adbping container for interactive testing
kubectl exec -it $podName -n adb-perf-test -- /bin/bash
~~~

Inside the container, run custom adbping tests:

~~~bash
# The adbping tool is pre-extracted and ready to use
which adbping
adbping --help

# Set your Oracle ADB connection details
export ADB_USER="admin"
export ADB_PASSWORD="Welcome1234#"  # Replace with your actual ADB password
export ADB_TNS=$trgConn  # Use the TNS connection string from docs\odaa-get-token.md

# Run custom performance tests
adbping -u "$ADB_USER" -p "$ADB_PASSWORD" -o -l "$ADB_TNS" -c java -t 5 -d 30
~~~

### 📊 Step 5: Performance Results Analysis

The adbping tool provides comprehensive metrics including:

- **Pass/Fail Counts**: Total successful/failed connections
- **SQL Execution Time**: Time to execute SQL only (excludes connection time)
- **Connect + SQL Time**: Total time including connection establishment
- **Percentile Analysis**: P90, P95, P99 latency metrics
- **Connection Pool Statistics**: Pool setup time and configuration

### 🧹 Step 6: Cleanup Resources

~~~powershell
# Exit the container (if using interactive mode)
exit

# Delete all performance testing resources
kubectl delete namespace adb-perf-test

# Remove the customized job file (optional)
Remove-Item "adbping-job-custom.yaml" -Force

# Verify cleanup
kubectl get namespaces | grep adb-perf-test
~~~

> **Note**: Deleting the namespace automatically removes all resources created within it, including deployments, jobs, and pods.

### 📈 Expected Results

Typical performance results you should expect:

~~~text
+++Test Summary+++
Test Client: java
Number of concurrent threads: 1
Duration (secs): 5
SQL executed: select 1 from dual;
Pass: 2665 Fail: 0
Test start date: 2025-11-04 19:44:24.593748+00:00
Test end date: 2025-11-04 19:44:35.576034+00:00
Java connection pool Stats: Initsize:1, Maxsize:1, Pool setup time(ms):4804.313
SQL Execution Time(ms) : Min:1.152 Max:74.072 Avg:1.67 Median:1.253 Perc90:1.393 Perc95:1.477 Perc99:4.691
Connect + SQL Execution Time(ms) : Min:1.183 Max:74.922 Avg:1.784 Median:1.316 Perc90:1.531 Perc95:1.664 Perc99:7.138
~~~

### 🔍 Performance Analysis Tips

1. **Latency Optimization**: Monitor P95 and P99 percentiles for consistent performance
2. **Throughput Analysis**: Calculate operations per second: `Pass Count / Duration`
3. **Connection Efficiency**: Compare SQL execution time vs. total connect+SQL time
4. **Scalability Testing**: Test with increasing thread counts to find optimal concurrency
5. **Network Impact**: Higher latencies may indicate network connectivity issues

[Back to workspace README](../../README.md)
