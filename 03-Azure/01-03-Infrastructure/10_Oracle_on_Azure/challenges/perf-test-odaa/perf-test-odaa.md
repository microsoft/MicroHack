# 🔌 Challenge 3: Perform Connectivity Tests on Oracle Database@azure [ODAA] Autonoumous Database

[Back to workspace README](../../README.md)

ODAA Autonoumous Database are so called PaaS (Platform as a Service) offerings, where the underlying infrastructure is fully managed by Microsoft and Oracle.

Installing tools like iperf, sockperf, etc is not possible on the ODAA ADB instance itself, as you would do it on a VM or Bare Metal server.

The following exercise will use the oracle instant client running inside the AKS cluster to connect via sqlplus to the ODAA Autonomous Database instance, and perform some simple latency measurements via SQL queries.

The SQL queries will measure the network round trips, elapsed time, DB time, and calculate the latency per round trip.

This is inspired from the blog of Clemens Bleile.

## 📋 Prerequisites

- 🔧 install Azure CLI
- ⚓ install kubectl

## 🔐 Login to Azure and set the right subscription

~~~bash
az login --use-device-code
# switch to the subscription where AKS is deployed
$subAKS="sub-team0" # replace with your AKS subscription name
# Make sure your cli points to the AKS subscription
az account set --subscription $subAKS
~~~

## 🌍 Define required environment variables

~~~bash
# log into your AKS cluster if not already done
$rgAKS="aks-team0" # replace with your AKS resource group name
$AKSClusterName="aks-team0" # replace with your AKS cluster name
~~~

## ⚓ Connect to AKS

~~~bash
# login to aks
az aks get-credentials -g $rgAKS -n $AKSClusterName --overwrite-existing
~~~

### 📡 SQL Ping Test from AKS to ODAA ADB

Reference the document [How to retrieve the Oracle Database Autonomous Database connection string from ODAA](../docs/odaa-get-token.md) to get the TNS connection string for your ODAA ADB instance.

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
sqlplus admin@'(description=(retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=gpdmotes.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_odaa2_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))' # replace with your TNS connection string
Welcome1234# # replace with your ADB password
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
SQL> 88770 ms elapsed time.
SQL> 77.008 ms DB time.
SQL> 53.141 ms latency per round trip.
SQL> --> (Elapsed Time - DB Time) / network round trips
~~~

> NOTE: There is as an alternative but with a bit more work to setup - the OCIPING/CONNPING tool created by Oracle’s Real World Performance team (actually part of a larger tool called rwloadsim):

### 📶 Test TCP Connection Time to ADB without sqlplus

The following method can be used to measure the TCP connection time from within the AKS cluster to the ADB instance.
It does establish a new TCP connection 10 times in a row and measures the time taken for each connection attempt.
This for sure include the TCP handshake time everytime and therefore the results will not be that accurate compared to the method described above.

~~~bash
# Test tcp connection time to ADB
bash -c 'H=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com;P=1522;for i in {1..10};do t0=$(date +%s%3N);(echo >/dev/tcp/$H/$P) &>/dev/null && dt=$(( $(date +%s%3N)-t0 )) || dt=-1;echo "$i: ${dt} ms";sleep 1;done' # replace with your ADB host
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

[Back to workspace README](../../README.md)