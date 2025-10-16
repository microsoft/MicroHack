# 🔌 Challenge 3: Perform Connectivity Tests

## 📋 Prerequisites

- 🔧 install Azure CLI
- ⚓ install kubectl
- 📦 install helm

## 🔐 Login to Azure and set the right subscription

~~~bash
az login --use-device-code
az account show
az account set -s <your-subscription-id>
~~~

## 🌍 Define required environment variables

~~~bash
rgName="<odaa-resource-group>"
prefix="<ODAA-prefix>"
location="<your-location>" # e.g. germanywestcentral
~~~

## ⚓ Connect to AKS

~~~bash
# login to aks
az aks get-credentials -g $rgName -n $prefix --overwrite-existing
# list namespaces
kubectl get namespaces # should show default, kube-system, kube-public
~~~

~~~text
NAME                STATUS   AGE
default             Active   9m41s
gatekeeper-system   Active   8m44s
ingress-nginx       Active   4m25s
kube-node-lease     Active   9m41s
kube-public         Active   9m41s
kube-system         Active   9m41s
~~~

## 📡 Ping Test from AKS to ODAA ADB

~~~powershell
# login to aks if not already done
az aks get-credentials -g $rgName -n $prefix --overwrite-existing
# extract the pod name of the instantcleint as it contains a random suffix
$podInstanteClientName=kubectl get pods -n microhacks | Select-String 'ogghack-goldengate-microhack-sample-instantclient' | ForEach-Object { ($_ -split '\s+')[0] }
# login to the pod ogghack-goldengate-microhack-sample-instantclient-5985df84vc5xs
kubectl exec -it -n microhacks $podInstanteClientName -- /bin/bash
# Test tcp connection time to ADB
bash -c 'H=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com;P=1522;for i in {1..10};do t0=$(date +%s%3N);(echo >/dev/tcp/$H/$P) &>/dev/null && dt=$(( $(date +%s%3N)-t0 )) || dt=-1;echo "$i: ${dt} ms";sleep 1;done'
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

~~~bash
# Example DIY quick test script (bash + sqlplus): 
sqlplus admin@'(description=(retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_adbger_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))'


bash -c 'start=$(date +%s%3N) sqlplus -s user/pass@TNS_ALIAS <<EOF > /dev/null select 1 from dual; exit EOF end=$(date +%s%3N) echo "One minimal query RTT: $((end-start)) ms"'
~~~

Explanation of: bash -c 'H=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com;P=1522;for i in {1..10};do t0=$(date +%s%3N);(echo >/dev/tcp/$H/$P) &>/dev/null && dt=$(( $(date +%s%3N)-t0 )) || dt=-1;echo "$i: ${dt} ms";sleep 1;done'

Breakdown:

bash -c '...' Runs the following single-quoted string in a new bash process (useful when you are currently in another shell).

H=...; P=1522; Sets host (H) and port (P) variables.

for i in {1..10}; do ...; done Simple brace expansion loop: i takes values 1 through 10.

t0=$(date +%s%3N) Captures start timestamp in milliseconds. %s = seconds since Unix epoch. %3N = first 3 digits of nanoseconds (i.e. milliseconds). Requires GNU date.

(echo >/dev/tcp/$H/$P) Bash special /dev/tcp/host/port pseudo-device: opening it makes bash attempt a TCP connection. echo sends a newline; parentheses run it in a subshell (not strictly needed here). If the TCP connect (and write) succeeds, exit status is 0; if it fails (timeout/refused), non‑zero.

&>/dev/null Redirects both stdout and stderr of the subshell command to /dev/null (silences output).

&& dt=$(( $(date +%s%3N)-t0 )) || dt=-1 Uses the prior command’s exit status:

If connect succeeded: recompute current time and subtract t0 → elapsed milliseconds in dt.
If failed: set dt to -1 as a sentinel. (Because of operator precedence, this works: (command) && success-part || failure-part.)
echo "$i: ${dt} ms" Prints iteration number and measured latency (or -1 meaning failure).

sleep 1 Waits 1 second between attempts to avoid hammering.

Net effect: Performs 10 successive TCP connect attempts to host:port, measuring approximate connect latency in milliseconds. Failures are reported as -1 ms.

Notes / caveats:

This measures TCP connect plus minimal write, not an application-layer (e.g. database handshake) latency.
Accuracy depends on system clock resolution; millisecond granularity is typical, jitter possible.
If DNS resolution is slow, only the first iteration pays that cost (cached later).
On systems without /dev/tcp (e.g. dash, some restricted shells, or macOS if using non-bash shell), this will fail.
On macOS older bash or BSD date: %3N not supported; would need an alternative (e.g. perl, python, or nanosecond timer).
To change attempts: adjust {1..10}.
To change interval: modify sleep 1.
To add timeout control: wrap with timeout command (Linux) e.g. timeout 2 bash -c '(echo >/dev/tcp/$H/$P)'.
Optional more portable variant (uses nc): for i in {1..10}; do t0=$(date +%s%3N); if nc -z -w2 "$H" "$P" 2>/dev/null; then dt=$(( $(date +%s%3N)-t0 )); else dt=-1; fi; echo "$i: ${dt} ms"; sleep 1; done


## Performance

~~~powershell
kubectl apply -f resources/infra/k8s/network-test-pod.yaml
# login to the pod
kubectl exec -it network-test-pod -- /bin/bash
~~~

~~~bash
dig +short eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com
# run tcping test
tcpping 10.0.1.165 1521
~~~

~~~text
2025-10-10T13:07:15+00:00 OK 10.0.1.165 1521 8ms
2025-10-10T13:07:16+00:00 OK 10.0.1.165 1521 7ms
2025-10-10T13:07:17+00:00 OK 10.0.1.165 1521 7ms
2025-10-10T13:07:18+00:00 OK 10.0.1.165 1521 9ms
2025-10-10T13:07:19+00:00 OK 10.0.1.165 1521 9ms
2025-10-10T13:07:20+00:00 OK 10.0.1.165 1521 5ms
2025-10-10T13:07:21+00:00 OK 10.0.1.165 1521 8ms
2025-10-10T13:07:22+00:00 OK 10.0.1.165 1521 18ms
2025-10-10T13:07:23+00:00 OK 10.0.1.165 1521 7ms
2025-10-10T13:07:24+00:00 OK 10.0.1.165 1521 7ms
2025-10-10T13:07:25+00:00 OK 10.0.1.165 1521 6ms
2025-10-10T13:07:26+00:00 OK 10.0.1.165 1521 6ms
2025-10-10T13:07:27+00:00 OK 10.0.1.165 1521 7ms
2025-10-10T13:07:28+00:00 OK 10.0.1.165 1521 7ms
2025-10-10T13:07:29+00:00 OK 10.0.1.165 1521 11ms
2025-10-10T13:07:30+00:00 OK 10.0.1.165 1521 8ms
2025-10-10T13:07:31+00:00 OK 10.0.1.165 1521 6ms
2025-10-10T13:07:32+00:00 OK 10.0.1.165 1521 9ms
2025-10-10T13:07:33+00:00 OK 10.0.1.165 1521 7ms
~~~

~~~bash
# run sockperf test
dig +short eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com
sockperf ping-pong -i 10.0.1.165 -p 1521 -t 60
~~~

# 
kubectl exec -it network-test-pod -c net-tools -- nmap -Pn -p 1521 --packet-trace --reason eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com


Test: 

kubectl exec -it network-test-pod -c net-tools -- tcpping eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com 1521 1 kubectl exec -it network-test-pod -c net-tools -- sockperf ping-pong -i 127.0.0.1 -p 11111 -t 5

kubectl exec -it network-test-pod -c net-tools -- dig +trace eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com kubectl exec -it network-test-pod -c net-tools -- ping -c 10 eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com




dig eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com +short
nslookup eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com
host eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com
# which os I am on
cat /etc/os-release
# install tcping on ubuntu


apt-get update && apt-get install -y tcping


~~~



## 🔗 Connect to ADB via sqlplus from within the pod

To connect to the ADB instance you will need the connection string. You can retrieve it via the Azure Portal from the ODAA ADB instance or use the Azure CLI:

~~~powershell
$adbName="ADBGer" # replace with your ADB name
# Prerequisites (if not already installed)
az extension add --name oracle-database 
# In case you need to switch subscription
az account set --subscription "ODAA"
az account show
$rgODAA="ODAA" # replace with your resource group name


# High profile (TCPS, tlsAuthentication = Server) - returns first match
$trgConn=az oracle-database autonomous-database show -g $rgODAA -n $adbName --query "connectionStrings.profiles[?consumerGroup=='High' && protocol=='TCPS' && tlsAuthentication=='Server'].value | [0]" -o tsv
echo $trgConn
~~~

## List Storages 

~~~powershell
kubectl get pods -n microhacks 
# extract the pod name as it contains a random suffix
$podName=kubectl get pods -n microhacks | Select-String 'ogghack-goldengate-microhack-sample-instantclient' | ForEach-Object { ($_ -split '\s+')[0] }

# login to the pod ogghack-goldengate-microhack-sample-instantclient-5985df84vc5xs
kubectl exec -it -n microhacks $podName -- /bin/bash
# connect to local Database on seperate pod
alias sql='sqlplus SH/Welcome1234#@//ogghack-goldengate-microhack-sample-db23ai:1521/FREEPDB1'
sql # connect to local db
# list directories
SELECT owner, directory_name, directory_path FROM   ALL_DIRECTORIES ORDER  BY owner, directory_name;
exit
~~~

## Verify SH user and GGADMIN user in ADB

~~~powershell
# log into ADB with admin via sqlplus
sqlplus admin@'(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_adbger_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))'
<your-ADB-password>
select USERNAME from ALL_USERS where USERNAME like 'SH%';
exit
# log into ADB with ggadmin user via sqlplus
sqlplus ggadmin@'(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_adbger_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))'
Welcome1234#
~~~

~~~text
USERNAME
--------------------------------------------------------------------------------
SH
~~~

~~~bash
select USERNAME, ACCOUNT_STATUS from DBA_USERS where USERNAME like 'GGADMIN';
~~~

~~~text
USERNAME
--------------------------------------------------------------------------------
ACCOUNT_STATUS
--------------------------------
GGADMIN
OPEN
~~~

~~~bash
connect ggadmin@'(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_adbger_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))'
Passw0rd1234
alter user ggadmin identified by Welcome1234#;
sqlplus ggadmin@'(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_adbger_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))'
Welcome1234#
show user;
exit
exit

# delete pod ogghack-goldengate-microhack-sample-db-prepare-job-pp86r
kubectl delete pod ogghack-goldengate-microhack-sample-db-prepare-job-pp86r -n microhacks
kubectl get pods -n microhacks
~~~
