# Oracle ADB Network Testing Container - Production Build# Connection and latency test tool for Oracle Autonomous Database - adbping



This directory contains the essential files for building the final production Oracle ADB network testing container with pre-extracted adbping tools.Based on: https://support.oracle.com/support/?kmContentId=2863450&page=sptemplate&sptemplate=km-article



## Essential FilesIn Oracle Autonomous Database on shared infrastructure, it is a common requirement for end customers and internal operations to quickly determine the latency while connecting to a particular service. A typical use case for such a test would be when a customer query or a workload is running with an unusually high latency and the user needs to ensure if the database service used by the workload, is healthy and is not having inherent latency issues impacting the workload / queries.



- **`Dockerfile`** - Production Docker build with pre-extracted adbping toolsadbping is an easy to use command line tool that can easily help end users determine the connection and SQL execution latency to benchmark the performance outside of their business workload. Tool is feature rich, allowing users to run the benchmark test with multitude of options including multi client support, multi threaded, configurable connection characteristics like pool size and other options. As of writing this content, we have the command line tool support on macOS and Linux.X64. Upcoming releases of the tool will have support for Windows as well.

- **`entrypoint.sh`** - Container entrypoint script with help and diagnostics  

- **`network-test.sh`** - Comprehensive network testing scriptSolution

- **`2863450.1-ADBPING_LINUX.X64-adbping_Linux.X64_230127.zip`** - Oracle adbping tool archivePre-requisites

- **`.dockerignore`** - Docker build context exclusionsPrior to running the adbing tool, please make sure the following pre-requisites are met.



## FeaturesOracle instant client, if you want to fetch sqlplus connection latency.



✅ **Pre-extracted adbping**: Tool is extracted and ready to use immediately  sudo dnf install oracle-instantclient-release-el8 -y // instant client basic

✅ **System-wide installation**: adbping available in PATH (`/usr/local/bin/adbping`)  sudo dnf install oracle-instantclient-basic -y // sql plus

✅ **Oracle JDBC drivers**: All required JAR files configured in CLASSPATH  sudo dnf install oracle-instantclient-sqlplus -y

✅ **Network testing tools**: dig, ping, traceroute, nc, curl, wget  

✅ **Security**: Runs as non-root user  Java JDK, if you want to fetch sqlplus connection latency.

✅ **Comprehensive diagnostics**: Built-in network testing capabilities  

sudo dnf install java-11-openjdk-devel -y 

## Quick Build & Testadbping tool is available for download from here



```bash

# Build the containerDownload from the following links, if the confluence link above is not accessible.

docker build -t adb-nettest:latest .

adbping_Linux.X64 - here

# Test adbping is ready

docker run --rm adb-nettest adbping --helpadbping_macOS - here



# Interactive accessadbping_Linux.X64_Windows - here

docker run --rm -it adb-nettest bash

```Tool Details



## Production UsageName

     adbping - ADB Ping and Latency Benchmarking Tool 1.0

```bash

# Run performance test with TNS connection stringSynopsis

docker run --rm adb-nettest adbping \

  -u admin -p "YourPassword" \adbping -u <user> -p <pwd> -s <service name> -w <wallet location> -i <instantclient home> -j <javahome> -t <threads> -d <duration> -c <client> -l <TLS URL>

  -l "YourTNSConnectionString" \Description

  -c java -t 3 -d 30      Connect and run a simple SQL and return the elapsed time statistics. SQL can be run in multiple concurrent threads and using various clients. As of version 1.0, we are supporting SQL*Plus and Java clients.



# Run with Oracle wallet  Options:

docker run --rm -v $(pwd)/wallet:/opt/oracle/wallet adb-nettest adbping \

  -u admin -p password -s service_name -w /opt/oracle/walletName:



# Network diagnostics        adbping - ADB Ping and Latency Benchmarking Tool 1.0

docker run --rm adb-nettest network-test all your-adb-host.oraclecloud.com

```Synopsis:



## Azure Container Registry Deployment        adbping -u <user> -p <pwd> -s <service name> -w <wallet location> -i <instantclient home> -j <javahome> -t <threads> -d <duration> -c <client>



```bashDescription:

# Tag for ACR

docker tag adb-nettest:latest your-registry.azurecr.io/adb-nettest:v2.1        Connect and run a simple SQL and return the elapsed time statistics. SQL can be run in multiple concurrent threads and using various clients.



# Push to ACR  Options:

docker push your-registry.azurecr.io/adb-nettest:v2.1

```-u / --username : Username to connect to the DB. If username option is not provided in the command line, user will be prompted to enter the username.



## Notes-p / --password : Password to connect to the DB. If password is not provided in the command line, user will be prompted to enter the password.



- This is the **final production version** incorporating all improvements-s / --service : Service name to connect. It can be any of the service names listed in the tnsnames.ora in the downloaded wallet. Example: dbname_tp/dbname_high

- The adbping tool is **pre-extracted** and immediately available

- All Oracle JDBC drivers are pre-configured in the CLASSPATH-t / --threads : Optional. Number of concurrent threads to be used to connect to the DB. Depending on the client type, there will be 't' parallel connection attempts spawned. Defaults to 1.

- For Kubernetes deployment, use the YAML files in the `resources\infra\k8s\` directory

-d / --duration : Optional. Duration in seconds to run the adbing. If not provided, adbping would run for one iteration of 't' parallel connections. Defaults to 5 secs.

## About adbping Tool

-n / --numconnections : Optional. Number of total connections to run. If numconnections is provided, then duration will be set to a max of 60 minutes and the test will execute till the total number of connections reach the numconnections or 60 minutes, whichever is earlier.

The adbping tool is Oracle's official connection and latency testing tool for Oracle Autonomous Database. It supports both wallet-based and one-way TLS connections with comprehensive performance metrics including percentile statistics.

-c / --testclient : Optional. In version 1.0, adbing can run the connection benchmarking test using 'SQL*Plus' and 'Java' clients. Valid input values are sqlplus / java. Defaults to sqlplus.

**Key Features:**

- Multi-threaded performance testing-e / --continueonerror : Optional. By default, the java client will abort the run when there is a pool error. -e option will let the tool to continue on error doing a pool recycle in case of pool based test (default).

- Java and SQLPlus client support  

- Connection pooling statistics-i / --instantclient : Optional. Instant client location is required if the adbping needs to be run using a specific client version. This input is optional if adbping can use the 'sqlplus' available in the PATH.

- CSV output for analysis

- Custom SQL file execution-j / --javahome : Optional. javahome location is required if the adbping needs to be run using a specific Java version. This input is optional if adbping can use 'java' available in the PATH.

- Comprehensive latency metrics (P90, P95, P99)

-o / --onewaytls : Flag to indicate that we need to connect with a one-way TLS URL. Any wallet location provided will be a no-op since we will use direct TLS url to connect.

For detailed adbping usage and options, run `docker run --rm adb-nettest adbping --help`
-l / --tlsurl : Optional. TLS connection URL obtained from Autonomous Database console -> DB connection -> TLS. This is mandatory when --onewaytls option is specified.

-q / --customsqlfile : Optional. Custom SQL file to execute for the connection test. SQL file can contain SQL statements or PL/SQL blocks. If not provided, the default connection test sql 'select 1 from dual' will be executed. Sample SQL files can be found in the samples folder. Custom sql files would be executed as is, with the specified client, so the script syntax should be compatible with respective client used.

-r / --trace : Optional. Enables finer debug tracing into adbping.trc file.

-f / --outputformat : Specify format option csv to print the test results in a csv format which can be used for result post processing. Default is to print the test summary in the adbping standard format.

-z / --jdbcoptions : Optional. Custom JDBC options can be provided in the input command line. Valid JDBC options are the following. One or more of these options can be provided as a comma separated list. Note: These options are for advanced users and we expect the user to be aware of the impact.

a.INIT_POOL_SIZE - Max pool size: if nothing is provided, defaults to threads count.

b.MIN_POOL_SIZE - Min pool size: if nothing is provided, defaults to threads count.

c.MAX_POOL_SIZE - Max pool size: if nothing is provided, defaults to threads count.

d.JDBC_PREFETCH_SIZE -

Example: -z 'INIT_POOL_SIZE=5,JDBC_PREFETCH_SIZE=25'

Example Usage

Case 1

Run one thread of SQL*Plus connection back to back for duration of 10 seconds. No test client (-c) option is specified. Uses "sqlplus" by default.
If -i / --instantclient option is not specified, then the tool uses "sqlplus" from PATH and if there is no "sqlplus" in PATH, the tool errors out.

$ ./adbping -u admin -p xxxxxxxx -w /home/opc/siraj/Wallet_db01 -c java -j /home/opc/siraj/jdk1.8.0_301 -s db01_low -d 30
+++Test Summary+++
Test Client: java
Number of concurrent threads: 1
Duration (secs): 30
SQL executed: select 1 from dual;
Pass: 27079 Fail: 0
Test start date: 2022-11-29 06:39:53.701708+00:00
Test end date: 2022-11-29 06:40:25.940934+00:00
Java connection pool Stats: Initsize:1, Maxsize:1, Pool setup time(ms):1713.559
SQL Execution Time(ms) : Min:0.423 Max:26.32 Avg:1.05 Median:0.819 Perc90:1.683 Perc95:2.156 Perc99:4.513
Connect + SQL Execution Time(ms) : Min:0.43 Max:26.34 Avg:1.07 Median:0.841 Perc90:1.698 Perc95:2.173 Perc99:4.528

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

Case 2

Run 5 parallel threads of JDBC client. Repeats for duration of 10 seconds.
If -c / --testclient java option is specified, then the tool uses "java" from path.
If the test needs to use a custom JDK, then the java home can be specified in -j / --javahome option

 

$ ./adbping -u admin -p xxxxxxxx -i /home/opc/instantclient_18_5 -w /home/opc/siraj/Wallet -s db002_high -t 1 -j /home/opc/jdk1.8.0_231 -c java -t 10 -d 30

+++Test Summary+++
Test Client: java
Number of concurrent threads: 10
Duration (secs): 30
Custom SQL executed: /adbadmin/satish/adbping/test.sql
Pass: 51709 Fail: 0
Test start date: 2022-11-29 23:02:30.157091+00:00
Test end date: 2022-11-29 23:03:18.777946+00:00
Java connection pool Stats: Initsize:1, Maxsize:1, Pool setup time(ms):17177.584
SQL Execution Time(ms) : Min:0.366 Max:31.755 Avg:0.515 Median:0.489 Perc90:0.596 Perc95:0.667 Perc99:1.023
Connect + SQL Execution Time(ms) : Min:0.38 Max:31.766 Avg:0.537 Median:0.508 Perc90:0.626 Perc95:0.719 Perc99:1.078

Case 3

Run 5 parallel threads of JDBC client. Repeats for duration of 10 seconds.
--onewaytls option along with the --tlsurl option can be used to run tests against the database using a One-way TLS URL
Reference docs:
How to configure DBs for one-way TLS - https://docs.oracle.com/en/cloud/paas/autonomous-database/adbsa/support-tls-mtls-authentication.html#GUID-6A34B30A-3692-4D1F-8458-FD8F32736199
How to setup ACLs for the DB - https://docs.oracle.com/en/cloud/paas/autonomous-database/adbsa/network-access-control-list-configure.html#GUID-B6389402-3F4D-45A2-A4DE-EAF1B31D8E50

$ ./adbping -u admin -p xxxxxxxx --onewaytls --tlsurl '(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=adb.us-ashburn-1.oraclecloud.com))(connect_data=(service_name=tenant_db_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)(ssl_server_cert_dn="CN=adwc.uscom-east-1.oraclecloud.com, OU=Oracle BMCS US, O=Oracle Corporation, L=Redwood City, ST=California, C=US")))' -t 1 -d 5 -c java -j /home/opc/siraj/jdk1.8.0_231

+++Test Summary+++
Test Client: java
Number of concurrent threads: 1
Duration (secs): 5
Custom SQL executed: select 1 from dual
Pass: 8540 Fail: 0
Test start date: 2022-11-29 23:02:30.157091+00:00
Test end date: 2022-11-29 23:03:52.777946+00:00
Java connection pool Stats: Initsize:1, Maxsize:1, Pool setup time(ms):17177.584
SQL Execution Time(ms) : Min:0.366 Max:31.755 Avg:0.515 Median:0.489 Perc90:0.596 Perc95:0.667 Perc99:1.023
Connect + SQL Execution Time(ms) : Min:0.38 Max:31.766 Avg:0.537 Median:0.508 Perc90:0.626 Perc95:0.719 Perc99:1.078

 Case 4:

Only Java client is allowed on Windows in this release of adbping.

Java client test using adbping on Windows machines.

C:\temp> adbping.exe -u admin -p xxxxxxx -w C:\Users\opc\Wallet_iad_regional -c java -o -l "(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=adb.us-ashburn-1.oraclecloud.com))(connect_data=(service_name=tenant_db_low.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))"

+++Test Summary+++
Test Client: java
Number of concurrent threads: 1
Duration (secs): 5
SQL executed: select 1 from dual;
JDBC Options:NA
Pass: 3052 Fail: 0
Test start date: 2023-03-01 19:30:25.537090+00:00
Test end date: 2023-03-01 19:30:39.307521+00:00
Java connection pool Stats: Initsize:1, Maxsize:1, Pool setup time(ms):8048.760
SQL Execution Time(ms) : Min:1.059 Max:27.683 Avg:1.457 Median:1.337 Perc90:1.63 Perc95:1.78 Perc99:2.911
Connect + SQL Execution Time(ms) : Min:1.087 Max:27.711 Avg:1.539 Median:1.397 Perc90:1.776 Perc95:1.961 Perc99:3.54

C:\temp> adbping.exe -u admin -p xxxxxx -s db_low -w C:\Users\opc\Wallet_iad_regional -c java

+++Test Summary+++
Test Client: java
Number of concurrent threads: 1
Duration (secs): 5
SQL executed: select 1 from dual;
JDBC Options:NA
Pass: 1756 Fail: 0
Test start date: 2023-03-01 19:32:34.408112+00:00
Test end date: 2023-03-01 19:32:47.922135+00:00
Java connection pool Stats: Initsize:1, Maxsize:1, Pool setup time(ms):7852.751
SQL Execution Time(ms) : Min:1.797 Max:211.033 Avg:2.62 Median:2.04 Perc90:2.311 Perc95:2.625 Perc99:7.547
Connect + SQL Execution Time(ms) : Min:1.83 Max:211.118 Avg:2.733 Median:2.137 Perc90:2.471 Perc95:2.823 Perc99:7.67

 


Attachments :
2863450.1-ADBPING_LINUX.X64-adbping_Linux.X64_230127.zip
2863450.1-ADBPING_MACOS-adbping_macOS_230130.zip
2863450.1-ADBPING_LIN_WIN-adbping_Linux.X64_Windows_230301.zip