# Challenge 4 - Perform Connectivity Tests

[Previous Challenge Solution](challenge-03.md) - **[Home](../Readme.md)** - [Next Challenge Solution](challenge-05.md)

## Goal 

The goal of this exercise is to test and measure network connectivity and latency between your AKS cluster and the Oracle Database@Azure (ODAA) Autonomous Database instance. You will perform connectivity tests to understand the network performance characteristics that will impact your applications.

## Actions

* Connect to your AKS cluster using kubectl
* Access the Oracle instant client pod running in your AKS cluster
* Establish a connection from the pod to the ODAA ADB instance using sqlplus
* Create test database objects and functions to measure network performance
* Execute SQL queries with different array sizes to measure network round trips and latency
* Analyze the relationship between elapsed time, DB time, and network latency
* Test TCP connection times to understand the baseline network performance

## Success criteria

* You have successfully connected to your AKS cluster and accessed the instant client pod
* You successfully established a sqlplus connection from the pod to the ODAA ADB instance
* You have created the test table (tlat) and performance measurement functions (net_roundtrips, my_db_time_microsecs)
* You have executed the test queries and captured metrics including:
  - Number of network round trips
  - Elapsed time
  - DB time
  - Latency per round trip
* You understand how array size settings impact the number of network round trips and overall performance
* You have measured TCP connection times and can explain the difference between TCP handshake time and query execution latency

## Learning resources
* [Oracle Net Services Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/)
* [SQL*Plus User's Guide and Reference](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/)
* [Performance Tuning with Array Fetch](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/tuning-sql.html)
* [Understanding Network Latency in Database Connections](https://learn.microsoft.com/en-us/azure/architecture/best-practices/network-latency)
