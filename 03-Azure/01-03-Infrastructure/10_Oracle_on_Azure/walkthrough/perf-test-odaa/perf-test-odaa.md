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

## 🚀 Performance Testing with ADBPing Tool from Azure Container Registry

The following section demonstrates how to connect to AKS, deploy a performance testing container from Azure Container Registry, and run comprehensive Oracle ADB performance tests using the `adbping` tool.


### Deploy ADBPing Container

Create a Kubernetes deployment for the adbping performance testing tool using external YAML files:

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

Execute comprehensive performance tests using the adbping tool. The recommended approach is using a Kubernetes Job for automated, repeatable testing.

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


## ConnPing Test (work in progress)

There is as an alternative but with a bit more work to setup - the OCIPING/CONNPING tool created by Oracle’s Real World Performance team (actually part of a larger tool called rwloadsim):

 

- Get a VM that can connect to ADB, with sqlplus installed

- Download the tool from https://github.com/oracle/rwloadsim/releases or from this link as a zip file: https://github.com/oracle/rwloadsim/releases/download/v.3.2.1/rwloadsim-linux-x86_64-bin-3.2.1.tgz

- set the profile - for example:

### User specific environment and startup programs

   export PATH=/home/opc/sw/bin:$PATH:$PATH                                        ----> path to the installation bin directory

   export LD_LIBRARY_PATH=/usr/lib/oracle/23/client64/lib:$LD_LIBRARY_PATH         ----> path to the Oracle Client

- test the latency (look for the ociping metric):

   connping -l admin/pass@"(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=…_tp.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))" --period=300                   ----> connection string for the ADB

 

Sample output – ociping is the metric to watch out for:


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

## 📶 Test TCP Connection Time to ADB

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
