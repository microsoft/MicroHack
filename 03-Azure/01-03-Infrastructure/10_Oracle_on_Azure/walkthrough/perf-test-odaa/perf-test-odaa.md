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

~~~

## 🚀 Performance Testing with ADBPing

### 🎯 What is ADBPing

The `adbping` tool is a performance testing utility specifically designed for Oracle Autonomous Databases (ADB). It allows you to measure various performance metrics such as connection latency, SQL execution time, and overall throughput when interacting with an Oracle ADB instance.

### Deploy ADBPing Container

~~~powershell
# Get pod name for interactive access
$podNameADBPing = kubectl get pods -n adb-perf-test -l app=adbping -o jsonpath="{.items[0].metadata.name}"
Write-Host "Pod Name: $podNameADBPing"
~~~

Output should be similar to:

~~~text
Pod Name: adbping-deployment-5cb699cd9c-mbgsn
~~~

### Configure and Run ADBPing Performance Tests Automated

**Prerequisites**: Ensure you have obtained the TNS connection string by following [docs\odaa-get-token.md](../../docs/odaa-get-token.md) and assigned it to the `$trgConn` variable. Similar to this:

~~~powershell
$trgConn="(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=zuyhervb.adb.eu-paris-1.oraclecloud.com))(connect_data=(service_name=gc2401553d1c7ab_uer00_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))"
~~~

~~~powershell
# Create a copy of the job template to avoid overwriting the original
Copy-Item "resources\infra\k8s\adbping-job.yaml" "adbping-job.yaml"

# Configure your ADB connection details

$ADB_PASSWORD = "<ADD-YOUR-PASSWORD-HERR>"  # Replace with your actual ADB password
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
          PASSWORD="****************"  # Your actual password
          TNS="(description= (retry_count=20)(retry_delay=3)...)"  # Your actual TNS string
~~~

Deploy and monitor the performance testing job:

~~~powershell
# Deploy the customized performance testing job
kubectl apply -f adbping-job.yaml

# Monitor the job progress
kubectl get jobs -n adb-perf-test -w
~~~

Initial output should look similar to:

~~~text
NAME                       STATUS    COMPLETIONS   DURATION   AGE
adbping-performance-test   Running   0/1           74s        74s
~~~

After a while you should see:

~~~text
NAME                       STATUS     COMPLETIONS   DURATION   AGE
adbping-performance-test   Complete   1/1           2m2s       2m8s
~~~

Use Key CTRL+C to exit the watch command.

~~~powershell
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
   Duration (secs): 90
   SQL executed: select 1 from dual;
   Pass: 341760 Fail: 0
   Test start date: 2025-11-14 07:34:22.005100+00:00
   Test end date: 2025-11-14 07:36:08.007073+00:00
   Java connection pool Stats: Initsize:3, Maxsize:3, Pool setup time(ms):6090.818
   SQL Execution Time(ms) : Min:0.543 Max:89.571 Avg:0.747 Median:0.653 Perc90:0.762 Perc95:0.778 Perc99:0.891
   Connect + SQL Execution Time(ms) : Min:0.549 Max:89.797 Avg:0.76 Median:0.661 Perc90:0.77 Perc95:0.791 Perc99:0.968

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

### Performance Results Analysis

The adbping tool provides comprehensive metrics including:

- **Pass/Fail Counts**: Total successful/failed connections
- **SQL Execution Time**: Time to execute SQL only (excludes connection time)
- **Connect + SQL Time**: Total time including connection establishment
- **Percentile Analysis**: P90, P95, P99 latency metrics
- **Connection Pool Statistics**: Pool setup time and configuration


### Interactive Testing of ADBPing(Advanced)

For interactive testing and custom test scenarios:

~~~powershell
# Enter the adbping container for interactive testing
kubectl exec -it $podNameADBPing -n adb-perf-test -- /bin/bash
~~~

Inside the container, run custom adbping tests:

~~~bash
# The adbping tool is pre-extracted and ready to use
which adbping
adbping --help

# Set your Oracle ADB connection details
export ADB_USER="admin"
export $ADB_PASSWORD = "<ADD-YOUR-PASSWORD-HERR>"  # Replace with your actual ADB password
export ADB_TNS="(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=zuyhervb.adb.eu-paris-1.oraclecloud.com))(connect_data=(service_name=gc2401553d1c7ab_uer00_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))"  # Use the TNS connection string from docs\odaa-get-token.md

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
   Pass: 379893 Fail: 0
   Test start date: 2025-11-14 07:41:47.368456+00:00
   Test end date: 2025-11-14 07:43:36.007844+00:00
   Java connection pool Stats: Initsize:5, Maxsize:5, Pool setup time(ms):5790.047
   SQL Execution Time(ms) : Min:0.848 Max:102.297 Avg:1.158 Median:0.999 Perc90:1.089 Perc95:1.119 Perc99:1.455
   Connect + SQL Execution Time(ms) : Min:0.855 Max:108.171 Avg:1.175 Median:1.008 Perc90:1.1 Perc95:1.136 Perc99:1.626

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

## 🚀 Performance Testing with ConnPing

### 🎯 What is Connping?

Connping is a performance testing tool based on Oracle's rwloadsim that measures:

- **ociping**: Database round-trip latency (primary metric)
- **dualping**: SQL execution time for `SELECT 1 FROM DUAL`
- **connect**: Session establishment time

<!-- ### Configure and Run Performance Tests Automated

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
# Apply the job (use original or modified yaml)
kubectl apply -f connping-job.yaml -n adb-perf-test

# Monitor the test progress
kubectl get jobs -n adb-perf-test --watch
~~~

Initial output should look similar to:

~~~text
NAME                        STATUS     COMPLETIONS   DURATION   AGE
connping-performance-test   Running    0/1           8s         8s
~~~

After a while you should see:

~~~text
NAME                        STATUS     COMPLETIONS   DURATION   AGE
connping-performance-test   Running    0/1           8s         8s
connping-performance-test   Running    0/1           9s         9s
connping-performance-test   Running    0/1           70s        70s
connping-performance-test   Running    0/1           71s        71s
connping-performance-test   Complete   1/1           71s        71s
~~~

Use Key CTRL+C to exit the watch command.

~~~powershell
# Then retrieve the test results
kubectl logs $podNameConnPing -n adb-perf-test
# View test results
kubectl logs job/connping-performance-test -n adb-perf-test
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

#### 📈 Understanding the Results

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
~~~ -->

### 🔄 Interactive Testing with ConnPing

~~~powershell
# Get pod name for interactive access
$podNameConnPing = kubectl get pods -n adb-perf-test -l app=connping -o jsonpath="{.items[0].metadata.name}"
Write-Host "Pod Name: $podNameConnPing"
~~~

Output should be similar to:

~~~text
Pod Name: connping-deployment-598bb45987-fqr9r
~~~

**Prerequisites**: Ensure you have obtained the TNS connection string by following [docs\odaa-get-token.md](../../docs/odaa-get-token.md) and assigned it to the `$trgConn` variable. Similar to this:

~~~powershell
$trgConn="(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=y1jilkjp.adb.eu-paris-1.oraclecloud.com))(connect_data=(service_name=gc2401553d1c7ab_user02_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))"
~~~

~~~powershell
# Configure your ADB connection details
$ADB_PASSWORD = "Welcome1234#"  # Replace with your actual ADB password
$ADB_TNS = $trgConn  # Use the TNS connection string obtained from docs\odaa-get-token.md
# Run an ad-hoc test
kubectl exec -it $podNameConnPing -n adb-perf-test -- connping -l "admin/$ADB_PASSWORD@$ADB_TNS" --period=90
~~~

Results should look similar to:

~~~text
RWP*Connect/OCIPing Release 3.2.1.0 Production on Fri, 14 Nov 2025 07:56:43 UTC
RWL-002: warning: public directory '/opt/rwloadsim/../public' is not accessible or does not appear correct
Connected default database with reconnect to:
Oracle Database 23ai Enterprise Edition Release 23.0.0.0.0 - for Oracle Cloud and Engineered Systems
connect:108.21 ms, ociping:1.125 ms, dualping:1.191 ms, sid=49476, inst#=1, time=1.1
connect:114.77 ms, ociping:0.999 ms, dualping:1.054 ms, sid=49476, inst#=1, time=2.1
connect:110.57 ms, ociping:0.891 ms, dualping:0.922 ms, sid=49476, inst#=1, time=3.1
connect:108.97 ms, ociping:0.874 ms, dualping:0.949 ms, sid=49476, inst#=1, time=4.1
connect:112.82 ms, ociping:1.033 ms, dualping:1.012 ms, sid=49476, inst#=1, time=5.1
connect:107.23 ms, ociping:0.802 ms, dualping:0.866 ms, sid=49476, inst#=1, time=6.1
connect:106.64 ms, ociping:0.883 ms, dualping:0.932 ms, sid=49476, inst#=1, time=7.1
connect:112.56 ms, ociping:0.877 ms, dualping:0.939 ms, sid=49476, inst#=1, time=8.1
connect:124.42 ms, ociping:0.843 ms, dualping:0.923 ms, sid=52345, inst#=1, time=9.1
connect:109.17 ms, ociping:0.878 ms, dualping:0.940 ms, sid=7174, inst#=1, time=10.1
connect:126.04 ms, ociping:0.954 ms, dualping:1.005 ms, sid=7174, inst#=1, time=11.1
connect:105.92 ms, ociping:0.931 ms, dualping:0.943 ms, sid=7174, inst#=1, time=12.1
connect:108.21 ms, ociping:1.081 ms, dualping:1.101 ms, sid=7174, inst#=1, time=13.1
connect:115.14 ms, ociping:0.835 ms, dualping:0.937 ms, sid=7174, inst#=1, time=14.1
connect:119.90 ms, ociping:0.956 ms, dualping:0.986 ms, sid=7174, inst#=1, time=15.1
connect:114.64 ms, ociping:0.953 ms, dualping:0.988 ms, sid=7174, inst#=1, time=16.1
connect:108.50 ms, ociping:0.953 ms, dualping:0.939 ms, sid=7174, inst#=1, time=17.1
connect:117.25 ms, ociping:1.127 ms, dualping:1.170 ms, sid=7174, inst#=1, time=18.1
connect:139.55 ms, ociping:0.899 ms, dualping:0.902 ms, sid=7174, inst#=1, time=19.2
connect:112.88 ms, ociping:1.079 ms, dualping:1.152 ms, sid=7174, inst#=1, time=20.1
connect:106.89 ms, ociping:1.074 ms, dualping:0.972 ms, sid=7174, inst#=1, time=21.1
connect:125.84 ms, ociping:0.915 ms, dualping:0.943 ms, sid=48520, inst#=1, time=22.1
connect:107.00 ms, ociping:0.960 ms, dualping:1.003 ms, sid=7174, inst#=1, time=23.1
connect:107.39 ms, ociping:0.997 ms, dualping:1.052 ms, sid=52345, inst#=1, time=24.1
connect:109.52 ms, ociping:1.039 ms, dualping:1.090 ms, sid=52345, inst#=1, time=25.1
connect:111.20 ms, ociping:0.918 ms, dualping:0.983 ms, sid=52345, inst#=1, time=26.1
connect:109.44 ms, ociping:0.956 ms, dualping:1.153 ms, sid=7174, inst#=1, time=27.1
connect:120.70 ms, ociping:0.979 ms, dualping:1.036 ms, sid=7174, inst#=1, time=28.1
connect:125.74 ms, ociping:1.023 ms, dualping:1.106 ms, sid=7174, inst#=1, time=29.1
connect:116.22 ms, ociping:0.921 ms, dualping:0.942 ms, sid=7174, inst#=1, time=30.1
connect:106.67 ms, ociping:0.966 ms, dualping:0.946 ms, sid=52345, inst#=1, time=31.1
connect:109.95 ms, ociping:0.919 ms, dualping:0.943 ms, sid=24382, inst#=1, time=32.1
connect:115.90 ms, ociping:0.971 ms, dualping:0.951 ms, sid=24382, inst#=1, time=33.1
connect:106.37 ms, ociping:0.878 ms, dualping:0.924 ms, sid=24382, inst#=1, time=34.1
connect:112.01 ms, ociping:1.073 ms, dualping:1.222 ms, sid=52345, inst#=1, time=35.1
connect:106.83 ms, ociping:0.952 ms, dualping:1.022 ms, sid=52345, inst#=1, time=36.1
connect:105.75 ms, ociping:0.880 ms, dualping:0.907 ms, sid=52345, inst#=1, time=37.1
connect:107.74 ms, ociping:0.894 ms, dualping:0.940 ms, sid=52345, inst#=1, time=38.1
connect:106.66 ms, ociping:0.982 ms, dualping:1.031 ms, sid=52345, inst#=1, time=39.1
connect:120.95 ms, ociping:0.924 ms, dualping:0.961 ms, sid=52345, inst#=1, time=40.1
connect:106.97 ms, ociping:0.918 ms, dualping:0.889 ms, sid=52345, inst#=1, time=41.1
connect:105.50 ms, ociping:0.920 ms, dualping:0.970 ms, sid=23666, inst#=1, time=42.1
connect:113.08 ms, ociping:0.917 ms, dualping:0.992 ms, sid=23666, inst#=1, time=43.1
connect:107.52 ms, ociping:0.894 ms, dualping:0.901 ms, sid=52345, inst#=1, time=44.1
connect:110.68 ms, ociping:0.940 ms, dualping:0.965 ms, sid=52345, inst#=1, time=45.1
connect:110.66 ms, ociping:0.892 ms, dualping:0.901 ms, sid=52345, inst#=1, time=46.1
connect:108.95 ms, ociping:0.837 ms, dualping:0.884 ms, sid=52345, inst#=1, time=47.1
connect:110.03 ms, ociping:1.051 ms, dualping:1.182 ms, sid=52345, inst#=1, time=48.1
connect:106.31 ms, ociping:0.928 ms, dualping:0.948 ms, sid=52345, inst#=1, time=49.1
connect:110.32 ms, ociping:1.037 ms, dualping:1.225 ms, sid=52345, inst#=1, time=50.1
connect:112.63 ms, ociping:0.990 ms, dualping:1.060 ms, sid=52345, inst#=1, time=51.1
connect:120.74 ms, ociping:0.878 ms, dualping:0.916 ms, sid=52345, inst#=1, time=52.1
connect:109.31 ms, ociping:1.007 ms, dualping:1.097 ms, sid=52345, inst#=1, time=53.1
connect:111.16 ms, ociping:1.016 ms, dualping:1.024 ms, sid=52345, inst#=1, time=54.1
connect:104.73 ms, ociping:0.802 ms, dualping:0.857 ms, sid=52345, inst#=1, time=55.1
connect:106.77 ms, ociping:0.965 ms, dualping:0.977 ms, sid=52345, inst#=1, time=56.1
connect:114.93 ms, ociping:0.999 ms, dualping:1.097 ms, sid=48520, inst#=1, time=57.1
connect:105.79 ms, ociping:0.851 ms, dualping:0.906 ms, sid=48520, inst#=1, time=58.1
connect:113.72 ms, ociping:0.893 ms, dualping:0.933 ms, sid=48520, inst#=1, time=59.1
connect:105.47 ms, ociping:0.843 ms, dualping:0.986 ms, sid=48520, inst#=1, time=60.1
connect:106.59 ms, ociping:0.873 ms, dualping:0.931 ms, sid=48520, inst#=1, time=61.1
connect:115.23 ms, ociping:1.000 ms, dualping:1.029 ms, sid=48520, inst#=1, time=62.1
connect:111.70 ms, ociping:0.930 ms, dualping:0.939 ms, sid=48520, inst#=1, time=63.1
connect:114.30 ms, ociping:0.999 ms, dualping:1.083 ms, sid=48520, inst#=1, time=64.1
connect:107.36 ms, ociping:0.922 ms, dualping:0.974 ms, sid=48520, inst#=1, time=65.1
connect:108.19 ms, ociping:1.080 ms, dualping:1.151 ms, sid=48520, inst#=1, time=66.1
connect:107.93 ms, ociping:0.808 ms, dualping:0.852 ms, sid=48520, inst#=1, time=67.1
connect:117.00 ms, ociping:0.915 ms, dualping:0.945 ms, sid=48520, inst#=1, time=68.1
connect:109.28 ms, ociping:0.875 ms, dualping:0.932 ms, sid=52345, inst#=1, time=69.1
connect:118.01 ms, ociping:1.041 ms, dualping:1.104 ms, sid=52345, inst#=1, time=70.1
connect:109.54 ms, ociping:0.959 ms, dualping:1.016 ms, sid=52345, inst#=1, time=71.1
connect:105.26 ms, ociping:0.832 ms, dualping:0.875 ms, sid=52345, inst#=1, time=72.1
connect:110.08 ms, ociping:0.873 ms, dualping:0.878 ms, sid=52345, inst#=1, time=73.1
connect:108.91 ms, ociping:0.956 ms, dualping:0.990 ms, sid=52345, inst#=1, time=74.1
connect:111.61 ms, ociping:0.978 ms, dualping:1.054 ms, sid=52345, inst#=1, time=75.1
connect:106.75 ms, ociping:0.840 ms, dualping:0.862 ms, sid=52345, inst#=1, time=76.1
connect:105.03 ms, ociping:0.963 ms, dualping:1.019 ms, sid=52345, inst#=1, time=77.1
connect:108.72 ms, ociping:1.032 ms, dualping:1.104 ms, sid=52345, inst#=1, time=78.1
connect:113.82 ms, ociping:0.957 ms, dualping:1.022 ms, sid=52345, inst#=1, time=79.1
connect:105.20 ms, ociping:0.863 ms, dualping:0.891 ms, sid=52345, inst#=1, time=80.1
connect:114.58 ms, ociping:1.078 ms, dualping:1.105 ms, sid=23666, inst#=1, time=81.1
connect:106.52 ms, ociping:1.116 ms, dualping:1.151 ms, sid=23666, inst#=1, time=82.1
connect:117.42 ms, ociping:1.013 ms, dualping:1.060 ms, sid=24382, inst#=1, time=83.1
connect:124.60 ms, ociping:0.877 ms, dualping:0.900 ms, sid=24382, inst#=1, time=84.1
connect:126.40 ms, ociping:1.253 ms, dualping:1.219 ms, sid=23666, inst#=1, time=85.1
connect:109.28 ms, ociping:0.918 ms, dualping:0.996 ms, sid=23666, inst#=1, time=86.1
connect:118.35 ms, ociping:0.917 ms, dualping:0.984 ms, sid=23666, inst#=1, time=87.1
connect:105.95 ms, ociping:0.925 ms, dualping:0.937 ms, sid=23666, inst#=1, time=88.1
connect:107.67 ms, ociping:0.974 ms, dualping:0.978 ms, sid=23666, inst#=1, time=89.1
connect mean=111.78, stddev=6.27, min=104.73, max=139.55
ociping mean=0.95, stddev=0.08, min=0.80, max=1.25
dualping mean=1.00, stddev=0.09, min=0.85, max=1.23
~~~

#### 📈 Understanding the Results

The output will show:

- **Real-time metrics**: Per-second latency measurements during the test
- **Summary statistics**:
  - `ociping mean`: Average round-trip latency
  - `connect mean`: Average connection establishment time
  - Standard deviation, min, and max values

## 🚀 Test TCP Connection Time to ADB (!!DONT!!)

The following method should **not be used** to measure the TCP connection time from within the AKS cluster to the ADB instance.
It does establish a new TCP connection 10 times in a row and measures the time taken for each connection attempt.
This for sure include the TCP handshake time everytime and therefore the results will not be that accurate compared to the method described above.

~~~powershell
# extract the pod name of the instantcleint as it contains a random suffix
$podInstanteClientName=kubectl get pods -n microhacks | Select-String 'ogghack-goldengate-microhack-sample-instantclient' | ForEach-Object { ($_ -split '\s+')[0] }
$podInstanteClientName
~~~

Output should be similar to:

~~~text
ogghack-goldengate-microhack-sample-instantclient-5985df84wp5c4
~~~

~~~powershell
# login to the pod InstanteClientName
kubectl exec -it -n microhacks $podInstanteClientName -- /bin/bash
~~~

Inside the instantclient pod, run the following commands to test TCP connection time to ADB

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

[Back to workspace README](../../README.md)