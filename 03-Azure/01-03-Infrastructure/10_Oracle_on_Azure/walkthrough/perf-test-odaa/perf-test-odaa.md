# 🔌 Challenge 3: Perform Connectivity Tests on Oracle Database@azure [ODAA] Autonoumous Database

[Back to workspace README](../../README.md)

ODAA Autonoumous Database are so called PaaS (Platform as a Service) offerings, where the underlying infrastructure is fully managed by Microsoft and Oracle.

Installing tools like iperf, sockperf, etc is not possible on the ODAA ADB instance itself, as you would do it on a VM or Bare Metal server.

The following exercise will use the oracle instant client running inside the AKS cluster to connect via sqlplus to the ODAA Autonomous Database instance, and perform some simple latency measurements via SQL queries.

The SQL queries will measure the network round trips, elapsed time, DB time, and calculate the latency per round trip.

This is inspired from the blog of Clemens Bleile.

## 🔐 Login to Azure and set the right subscription

~~~powershell

az login --use-device-code
# switch to the subscription where AKS is deployed

$subAKS="sub-mh2" # replace with your AKS subscription name

# Make sure your cli points to the AKS subscription
az account set --subscription $subAKS

# log into your AKS cluster if not already done
$rgAKS="rg-aks-user02" # replace with your AKS resource group name
$AKSClusterName="aks-user02" # replace with your AKS cluster name
# login to aks
az aks get-credentials -g $rgAKS -n $AKSClusterName --overwrite-existing

# extract the pod name of the instantcleint as it contains a random suffix
$podInstanteClientName=kubectl get pods -n microhacks | Select-String 'ogghack-goldengate-microhack-sample-instantclient' | ForEach-Object { ($_ -split '\s+')[0] }
~~~

## 🚀 Performance Testing with ADBPing

### 🎯 What is ADBPing

The `adbping` tool is a performance testing utility specifically designed for Oracle Autonomous Databases (ADB). It allows you to measure various performance metrics such as connection latency, SQL execution time, and overall throughput when interacting with an Oracle ADB instance.

### Deploy ADBPing Container

~~~powershell
# Deploy namespace and ADBPing container using external YAML files
kubectl apply -f resources\infra\k8s\namespace.yaml,resources\infra\k8s\adbping-deployment.yaml
kubectl get pods -n adb-perf-test

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=adbping -n adb-perf-test --timeout=300s

# Get pod name for interactive access
$podName = kubectl get pods -n adb-perf-test -l app=adbping -o jsonpath="{.items[0].metadata.name}"
Write-Host "Pod Name: $podName"
~~~

### Configure and Run Performance Tests Automated

**Prerequisites**: Ensure you have obtained the TNS connection string by following [docs\odaa-get-token.md](../../docs/odaa-get-token.md) and assigned it to the `$trgConn` variable. Similar to this:

~~~powershell
$trgConn="(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=y1jilkjp.adb.eu-paris-1.oraclecloud.com))(connect_data=(service_name=gc2401553d1c7ab_user02_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))"
~~~

~~~powershell
# Create a copy of the job template to avoid overwriting the original
Copy-Item "resources\infra\k8s\adbping-job.yaml" "adbping-job.yaml"

# Configure your ADB connection details

$ADB_PASSWORD = "Welcome1234#"  # Replace with your actual ADB password
$ADB_TNS = $trgConn  # Use the TNS connection string obtained from docs\odaa-get-token.md

# Update the job configuration with your credentials
(Get-Content adbping-job.yaml) -replace 'YOUR_PASSWORD_HERE', $ADB_PASSWORD | Set-Content adbping-job.yaml
(Get-Content adbping-job.yaml) -replace 'YOUR_TNS_CONNECTION_STRING_HERE', $ADB_TNS | Set-Content adbping-job.yaml


# Verify the changes - show the updated configuration lines
(Get-Content adbping-job.yaml)[23..26] | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
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
kubectl apply -f adbping-job.yaml

# Monitor the job progress
kubectl get jobs -n adb-perf-test

# Wait for job to complete and view results
kubectl wait --for=condition=complete job/adbping-performance-test -n adb-perf-test --timeout=300s

# View test results
kubectl logs job/adbping-performance-test -n adb-perf-test
~~~

Results should look similar to:

~~~text
🚀 Oracle ADB Performance Test
==============================
📊 Starting performance test...
Threads: 3, Duration: 30 seconds

+++Test Summary+++
   Test Client: java
   Number of concurrent threads: 3
   Duration (secs): 30
   SQL executed: select 1 from dual;
   Pass: 56552 Fail: 0
   Test start date: 2025-11-13 11:49:58.423862+00:00
   Test end date: 2025-11-13 11:50:38.267820+00:00
   Java connection pool Stats: Initsize:3, Maxsize:3, Pool setup time(ms):5318.288
   SQL Execution Time(ms) : Min:1.091 Max:207.241 Avg:1.566 Median:1.186 Perc90:1.294 Perc95:1.348 Perc99:1.891
   Connect + SQL Execution Time(ms) : Min:1.101 Max:207.248 Avg:1.595 Median:1.202 Perc90:1.32 Perc95:1.394 Perc99:2.173

Interpretation of the results
-----------------------------

        1. Pass/Fail count: Indicates the total number of connections passed/failed in defined duration by the defined number of threads.

        2. SQL execution time: Time taken to just execute the SQL. Connection time not included.
           For sqlplus, this would be the elapsed time reported by sqlplus.

        3. Connect + SQL Execution Time: Time taken to connect and execute SQL.
           For sqlplus, this would be the time to connect and run the sql.
           For java, it would be time taken to getConnection() and execute the query.

        4. Java connection pool stats: Reports the time taken to setup the java connection pool and the initial and max size.
           All query executions do a getConnection() and execute the SQL.

        5. Perc90, Perc95, Perc99: This is the percentile value indicating 90%, 95% or 99% of the latencies are below the respective value.

✅ Performance test completed!
~~~

View job logs and status for further analysis:

~~~powershell
# Alternative: View logs by label (if needed)
kubectl logs -l job-name=adbping-performance-test -n adb-perf-test
~~~

### Interactive Testing (Advanced)

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
export ADB_TNS="(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=y1jilkjp.adb.eu-paris-1.oraclecloud.com))(connect_data=(service_name=gc2401553d1c7ab_user02_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))"  # Use the TNS connection string from docs\odaa-get-token.md

# Run custom performance tests
adbping -u "$ADB_USER" -p "$ADB_PASSWORD" -o -l "$ADB_TNS" -c java -t 5 -d 90
~~~

Results will be similar to the automated job output.

~~~text
+++Test Summary+++
   Test Client: java
   Number of concurrent threads: 5
   Duration (secs): 90
   SQL executed: select 1 from dual;
   Pass: 328188 Fail: 0
   Test start date: 2025-11-13 12:05:24.852019+00:00
   Test end date: 2025-11-13 12:07:12.266286+00:00
   Java connection pool Stats: Initsize:5, Maxsize:5, Pool setup time(ms):5596.033
   SQL Execution Time(ms) : Min:1.057 Max:209.796 Avg:1.353 Median:1.165 Perc90:1.266 Perc95:1.34 Perc99:1.904
   Connect + SQL Execution Time(ms) : Min:1.066 Max:209.803 Avg:1.368 Median:1.173 Perc90:1.279 Perc95:1.363 Perc99:2.052

Interpretation of the results
-----------------------------

        1. Pass/Fail count: Indicates the total number of connections passed/failed in defined duration by the defined number of threads.

        2. SQL execution time: Time taken to just execute the SQL. Connection time not included.
           For sqlplus, this would be the elapsed time reported by sqlplus.

        3. Connect + SQL Execution Time: Time taken to connect and execute SQL.
           For sqlplus, this would be the time to connect and run the sql.
           For java, it would be time taken to getConnection() and execute the query.

        4. Java connection pool stats: Reports the time taken to setup the java connection pool and the initial and max size.
           All query executions do a getConnection() and execute the SQL.

        5. Perc90, Perc95, Perc99: This is the percentile value indicating 90%, 95% or 99% of the latencies are below the respective value.
~~~

### Performance Results Analysis

The adbping tool provides comprehensive metrics including:

- **Pass/Fail Counts**: Total successful/failed connections
- **SQL Execution Time**: Time to execute SQL only (excludes connection time)
- **Connect + SQL Time**: Total time including connection establishment
- **Percentile Analysis**: P90, P95, P99 latency metrics
- **Connection Pool Statistics**: Pool setup time and configuration

### Cleanup Resources

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

### Expected Results

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

### Performance Analysis Tips

1. **Latency Optimization**: Monitor P95 and P99 percentiles for consistent performance
2. **Throughput Analysis**: Calculate operations per second: `Pass Count / Duration`
3. **Connection Efficiency**: Compare SQL execution time vs. total connect+SQL time
4. **Scalability Testing**: Test with increasing thread counts to find optimal concurrency
5. **Network Impact**: Higher latencies may indicate network connectivity issues

<!-- ## 📡 SQL Ping Test from AKS to ODAA ADB

The following test is a DIY of an Oracle ADB and currently not recommended.

You will need the TNS connection string.

Reference the document [How to retrieve the Oracle Database Autonomous Database connection string from ODAA](../../docs/odaa-get-token.md) to get the TNS connection string for your ODAA ADB instance.

~~~powershell
# login to the pod InstanteClientName
kubectl exec -it -n microhacks $podInstanteClientName -- /bin/bash
~~~

Inside the instantclient pod, run the following commands:

~~~bash
sqlplus admin@'(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=y1jilkjp.adb.eu-paris-1.oraclecloud.com))(connect_data=(service_name=gc2401553d1c7ab_user02_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))' # replace with your TNS connection string
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

Run test:

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
exec dbms_output.put_line('-> (Elapsed Time - DB Time) / network round trips');
set echo off
~~~

~~~text
5000 rows selected.

SQL>   2    3    4    5    6  
PL/SQL procedure successfully completed.

SQL> SQL> 1669 network round trips.
SQL> 11890 ms elapsed time.
SQL> 56.589 ms DB time.
SQL> 7.09 ms latency per round trip.
SQL> -> (Elapsed Time - DB Time) / network round trips
SQL> SQL>
~~~

Exit the sqlplus client

~~~bash
exit
~~~

Exit Pod

~~~bash
exit
~~~ -->



## 🚀 Performance Testing with ConnPing

### 🎯 What is Connping?

Connping is a performance testing tool based on Oracle's rwloadsim that measures:

- **ociping**: Database round-trip latency (primary metric)
- **dualping**: SQL execution time for `SELECT 1 FROM DUAL`
- **connect**: Session establishment time

### 📦 Deploying Connping in AK

~~~powershell
# Deploy namespace and ADBPing container using external YAML files
kubectl apply -f resources\infra\k8s\connping-deployment.yaml
kubectl get pods -n adb-perf-test

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=connping -n adb-perf-test --timeout=300s

# Get pod name for interactive access
$podNameConnPing = kubectl get pods -n adb-perf-test -l app=connping -o jsonpath="{.items[0].metadata.name}"
Write-Host "Pod Name: $podNameConnPing"
~~~

### Configure and Run Performance Tests Automated

**Prerequisites**: Ensure you have obtained the TNS connection string by following [docs\odaa-get-token.md](../../docs/odaa-get-token.md) and assigned it to the `$trgConn` variable. Similar to this:

~~~powershell
$trgConn="(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=y1jilkjp.adb.eu-paris-1.oraclecloud.com))(connect_data=(service_name=gc2401553d1c7ab_user02_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))"
~~~

~~~powershell
# Create a copy of the job template to avoid overwriting the original
Copy-Item "resources\infra\k8s\connping-job.yaml " "connping-job.yaml"

# Configure your ADB connection details

$ADB_PASSWORD = "Welcome1234#"  # Replace with your actual ADB password
$ADB_TNS = $trgConn  # Use the TNS connection string obtained from docs\odaa-get-token.md

# Update the job with your connection details
(Get-Content connping-job.yaml) -replace 'YOUR_PASSWORD_HERE', $ADB_PASSWORD | Set-Content connping-job.yaml
(Get-Content connping-job.yaml) -replace 'YOUR_TNS_CONNECTION_STRING_HERE', $ADB_TNS | Set-Content connping-job.yaml

# Verify the changes - show the updated configuration lines
(Get-Content connping-job.yaml)[23..26] | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
~~~

The updated configuration should look like this:

~~~yaml
            USER="admin"
            PASSWORD="Welcome1234#"
            TNS="(description= (retry_count=20)(retry_delay=3)(address..."
~~~

Deploy and monitor the performance testing job:

~~~powershell
# Delete previous test if exists
kubectl delete job connping-performance-test -n adb-perf-test --ignore-not-found=true

# Apply the job (use original or modified yaml)
kubectl apply -f connping-job.yaml -n adb-perf-test

# Monitor the test progress
kubectl get jobs -n adb-perf-test --watch

# Wait for the job to complete (default: 300 seconds / 5 minutes)
$podName = kubectl get pods -n adb-perf-test -l job-name=connping-performance-test -o jsonpath='{.items[0].metadata.name}'
# Then retrieve the test results
kubectl logs $podName -n adb-perf-test
~~~

Results should look similar to:

~~~text
🚀 Oracle ADB Connping Performance Test
==============================
📊 Starting connping test with statistics...
Duration: 300 seconds (--period=300)
Options: -ss (statistics with histograms for percentiles/median)
Watch for the 'ociping' metric and summary statistics in the output

RWL-002: warning: public directory '/opt/rwloadsim/../public' is not accessible or does not appear correct
RWL-094: warning at [connping.rwl;257]: cannot save statistics without a results database

RWP*Connect/OCIPing Release 3.2.1.0 Production on Thu, 13 Nov 2025 17:23:24 UTC
Connected default database with reconnect to:
Oracle Database 23ai Enterprise Edition Release 23.0.0.0.0 - for Oracle Cloud and Engineered Systems
connect:110.78 ms, ociping:1.204 ms, dualping:1.267 ms, sid=28207, inst#=3, time=1.1
connect:110.97 ms, ociping:1.237 ms, dualping:1.297 ms, sid=28207, inst#=3, time=2.1
connect:113.50 ms, ociping:1.201 ms, dualping:1.460 ms, sid=24383, inst#=3, time=3.1
connect:121.32 ms, ociping:1.181 ms, dualping:1.292 ms, sid=24383, inst#=3, time=4.1
connect:121.17 ms, ociping:1.228 ms, dualping:1.270 ms, sid=28207, inst#=3, time=5.1
connect:123.94 ms, ociping:1.280 ms, dualping:1.297 ms, sid=28207, inst#=3, time=6.1
connect:109.62 ms, ociping:1.237 ms, dualping:1.292 ms, sid=28207, inst#=3, time=7.1
connect:141.65 ms, ociping:1.157 ms, dualping:1.213 ms, sid=24383, inst#=3, time=8.2
connect:112.49 ms, ociping:1.434 ms, dualping:1.475 ms, sid=24383, inst#=3, time=9.1
connect:115.98 ms, ociping:1.443 ms, dualping:1.460 ms, sid=24383, inst#=3, time=10.1
connect:109.42 ms, ociping:1.287 ms, dualping:1.296 ms, sid=24383, inst#=3, time=11.1
connect:116.43 ms, ociping:1.159 ms, dualping:1.217 ms, sid=24383, inst#=3, time=12.1
connect:109.47 ms, ociping:1.209 ms, dualping:1.203 ms, sid=24383, inst#=3, time=13.1
connect:110.31 ms, ociping:1.161 ms, dualping:1.211 ms, sid=24383, inst#=3, time=14.1
connect:110.97 ms, ociping:1.237 ms, dualping:1.249 ms, sid=24383, inst#=3, time=15.1
connect:108.76 ms, ociping:1.267 ms, dualping:1.262 ms, sid=24383, inst#=3, time=16.1
connect:115.79 ms, ociping:1.248 ms, dualping:1.270 ms, sid=24383, inst#=3, time=17.1
connect:109.25 ms, ociping:1.175 ms, dualping:1.176 ms, sid=28207, inst#=3, time=18.1
connect:135.44 ms, ociping:1.257 ms, dualping:1.310 ms, sid=31553, inst#=3, time=19.1
connect:112.38 ms, ociping:1.211 ms, dualping:1.275 ms, sid=24383, inst#=3, time=20.1
connect:111.77 ms, ociping:1.169 ms, dualping:1.143 ms, sid=24383, inst#=3, time=21.1
connect:111.24 ms, ociping:1.199 ms, dualping:1.255 ms, sid=24383, inst#=3, time=22.1
connect:110.20 ms, ociping:1.301 ms, dualping:1.296 ms, sid=24383, inst#=3, time=23.1
connect:122.16 ms, ociping:1.407 ms, dualping:1.491 ms, sid=31553, inst#=3, time=24.1
connect:122.72 ms, ociping:1.234 ms, dualping:1.320 ms, sid=24383, inst#=3, time=25.1
connect:111.90 ms, ociping:1.248 ms, dualping:1.299 ms, sid=24383, inst#=3, time=26.1
connect:111.38 ms, ociping:1.318 ms, dualping:1.510 ms, sid=24383, inst#=3, time=27.1
connect:109.20 ms, ociping:1.185 ms, dualping:1.212 ms, sid=24383, inst#=3, time=28.1
connect:112.67 ms, ociping:1.230 ms, dualping:1.340 ms, sid=24383, inst#=3, time=29.1
connect:120.68 ms, ociping:1.162 ms, dualping:1.181 ms, sid=24383, inst#=3, time=30.1
connect:115.94 ms, ociping:1.153 ms, dualping:1.211 ms, sid=30834, inst#=3, time=31.1
connect:117.18 ms, ociping:1.589 ms, dualping:1.586 ms, sid=30834, inst#=3, time=32.1
connect:110.73 ms, ociping:1.454 ms, dualping:1.304 ms, sid=30834, inst#=3, time=33.1
connect:117.34 ms, ociping:1.238 ms, dualping:1.428 ms, sid=30834, inst#=3, time=34.1
connect:123.87 ms, ociping:1.203 ms, dualping:1.184 ms, sid=30834, inst#=3, time=35.1
connect:110.38 ms, ociping:1.230 ms, dualping:1.219 ms, sid=30834, inst#=3, time=36.1
connect:111.64 ms, ociping:1.201 ms, dualping:1.494 ms, sid=30834, inst#=3, time=37.1
connect:131.82 ms, ociping:1.132 ms, dualping:1.190 ms, sid=30834, inst#=3, time=38.1
connect:114.00 ms, ociping:1.196 ms, dualping:1.270 ms, sid=34658, inst#=3, time=39.1
connect:143.81 ms, ociping:1.314 ms, dualping:1.371 ms, sid=34658, inst#=3, time=40.2
connect:112.98 ms, ociping:1.113 ms, dualping:1.181 ms, sid=34658, inst#=3, time=41.1
connect:121.39 ms, ociping:1.166 ms, dualping:1.214 ms, sid=34658, inst#=3, time=42.1
connect:110.73 ms, ociping:1.315 ms, dualping:1.268 ms, sid=35377, inst#=3, time=43.1
connect:110.97 ms, ociping:1.224 ms, dualping:1.228 ms, sid=35377, inst#=3, time=44.1
connect:109.71 ms, ociping:1.118 ms, dualping:1.140 ms, sid=34658, inst#=3, time=45.1
~~~

### 📈 Understanding the Results

The output will show:

- **Real-time metrics**: Per-second latency measurements during the test
- **Summary statistics**:
  - `ociping mean`: Average round-trip latency (e.g., 1.24 ms)
  - `connect mean`: Average connection establishment time (e.g., 119 ms)
  - Standard deviation, min, and max values

**Example output:**

~~~text
connect mean=119.27, stddev=35.76, min=105.18, max=581.60
ociping mean=1.24, stddev=0.09, min=1.08, max=1.66
dualping mean=1.29, stddev=0.11, min=1.14, max=2.21
~~~

### 🎛️ Customizing the Test

You can modify the test duration and statistics options by editing `connping-job.yaml`:

~~~yaml
command: 
  - "/bin/sh"
  - "-c"
  - |
    echo "Starting connping test..."
    connping -ss -l "admin/$(ADB_PASSWORD)@$(TNS_CONNECTION)" --period=300
~~~

**Options:**

- `--period=N`: Test duration in seconds (default: 300)
- `-s`: Basic statistics
- `-ss`: Statistics with histograms (includes percentiles)
- `-sss`: Per-second statistics

### 🔄 Interactive Testing

For interactive testing, you can also use the connping deployment:

~~~powershell
# Get the deployment pod name
$podName = kubectl get pods -n adb-perf-test -l app=connping -o jsonpath='{.items[0].metadata.name}'

# Run an ad-hoc test
kubectl exec -it $podName -n adb-perf-test -- connping -l "admin/$ADB_PASSWORD@$ADB_TNS" --period=90
~~~

## 🚀 Test TCP Connection Time to ADB

The following method can be used to measure the TCP connection time from within the AKS cluster to the ADB instance.
It does establish a new TCP connection 10 times in a row and measures the time taken for each connection attempt.
This for sure include the TCP handshake time everytime and therefore the results will not be that accurate compared to the method described above.

~~~powershell
# login to the pod InstanteClientName
kubectl exec -it -n microhacks $podInstanteClientName -- /bin/bash
~~~

~~~bash
# You should still be logged in into the pod
# Test tcp connection time to ADB
bash -c 'H=y1jilkjp.adb.eu-paris-1.oraclecloud.com;P=1521;for i in {1..10};do t0=$(date +%s%3N);(echo >/dev/tcp/$H/$P) &>/dev/null && dt=$(( $(date +%s%3N)-t0 )) || dt=-1;echo "$i: ${dt} ms";sleep 1;done' # replace with your ADB host
~~~

Results should look similar to:

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

Exit the pod

~~~bash
exit
~~~

[Back to workspace README](../../README.md)