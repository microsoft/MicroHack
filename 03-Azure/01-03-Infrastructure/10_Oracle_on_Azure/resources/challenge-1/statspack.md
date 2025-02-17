The following section explain how to create an oracle statspacke level 7 for 
1. express edtion, 
2. standard edition and 
3. standard edition 2

For enterprise editions without the required license statspack report need to be created as well.

The section 2 is for Oracle customers who have the appropriate enterprise editions and additional licenses available to use the modern AWR reports (Automatic Repository Workload Report). 

Please clarify internal if your licenses or contract with kind of report can be used


# Create / Generate a statspack report level 7 for discovery purposes

~~~bash
oracle@oracle-xe1:~$ sqlplus / as sysdba
~~~

SQL*Plus: Release 11.2.0.2.0 Production on Sun Feb 9 16:54:21 2025

Copyright (c) 1982, 2011, Oracle.  All rights reserved.


Connected to:
Oracle Database 11g Express Edition Release 11.2.0.2.0 - 64bit Production

~~~bash
SQL> @?/rdbms/admin/spcreate.sql


Choose the PERFSTAT user's password
-----------------------------------
Not specifying a password will result in the installation FAILING

Enter value for perfstat_password: passw0rd
passw0rd


Choose the Default tablespace for the PERFSTAT user
---------------------------------------------------
Below is the list of online tablespaces in this database which can
store user data.  Specifying the SYSTEM tablespace for the user's
default tablespace will result in the installation FAILING, as
using SYSTEM for performance data is not supported.

Choose the PERFSTAT users's default tablespace.  This is the tablespace
in which the STATSPACK tables and indexes will be created.

TABLESPACE_NAME                CONTENTS  STATSPACK DEFAULT TABLESPACE
------------------------------ --------- ----------------------------
SYSAUX                         PERMANENT *
USERS                          PERMANENT

Pressing <return> will result in STATSPACK's recommended default
tablespace (identified by *) being used.

Enter value for default_tablespace:

Using tablespace SYSAUX as PERFSTAT default tablespace.


Choose the Temporary tablespace for the PERFSTAT user
-----------------------------------------------------
Below is the list of online tablespaces in this database which can
store temporary data (e.g. for sort workareas).  Specifying the SYSTEM
tablespace for the user's temporary tablespace will result in the
installation FAILING, as using SYSTEM for workareas is not supported.

Choose the PERFSTAT user's Temporary tablespace.

TABLESPACE_NAME                CONTENTS  DB DEFAULT TEMP TABLESPACE
------------------------------ --------- --------------------------
TEMP                           TEMPORARY *

Pressing <return> will result in the database's default Temporary
tablespace (identified by *) being used.

Enter value for temporary_tablespace:

Using tablespace TEMP as PERFSTAT temporary tablespace.


... Creating PERFSTAT user


... Installing required packages
~~~



## SPCPKG complete. Please check spcpkg.lis for any errors.
~~~bash
cd $ORACLE_HOME/rdbms/admin

cat spcpkg.lis

or

less spcpkg.lis
~~~

## Execute the statspack.snap procedure to take a snapshot at level 7.
~~~bash
SQL> conn / as sysdba
Connected.

SQL> EXEC statspack.snap(i_snap_level => 7);

PL/SQL procedure successfully completed.
~~~


## Run the spreport.sql script to generate the STATSPACK report.

~~~bash
sqlplus / as sysdba

@?/rdbms/admin/spreport.sql



Current Instance


   DB Id    DB Name      Inst Num Instance
----------- ------------ -------- ------------
 2881346253 XE                  1 XE



Instances in this Statspack schema


   DB Id    Inst Num DB Name      Instance     Host
----------- -------- ------------ ------------ ------------
 2881346253        1 XE           XE           oracle-xe1

Using 2881346253 for database Id
Using          1 for instance number


Specify the number of days of snapshots to choose from

Entering the number of days (n) will result in the most recent
(n) days of snapshots being listed.  Pressing <return> without
specifying a number lists all completed snapshots.



Listing all Completed Snapshots

Instance     DB Name        Snap Id   Snap Started    Level Comment
------------ ------------ --------- ----------------- ----- --------------------
XE           XE                   1 09 Feb 2025 17:01     7



Specify the Begin and End Snapshot Ids

Enter value for begin_snap:
~~~


# If the STATSPACK job does not exist, create it
~~~bash
BEGIN
  DBMS_SCHEDULER.CREATE_JOB (
    job_name        => 'STATSPACK_JOB',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN statspack.snap(i_snap_level => 7); END;',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=HOURLY; INTERVAL=1',
    enabled         => TRUE
  );
END;
/

# Change the interval of the scheduled job
BEGIN
  DBMS_SCHEDULER.SET_ATTRIBUTE (
    name            => 'STATSPACK_JOB',
    attribute       => 'repeat_interval',
    value           => 'FREQ=MINUTELY;INTERVAL=1'  -- Change this to your desired interval
  );
END;
/
~~~
# Verify the STATSPACK job
SELECT job_name, schedule_name, start_date, repeat_interval
FROM dba_scheduler_jobs
WHERE job_name LIKE 'STATSPACK%';



Finally copy to statspack report from the oracle-xe1 container on your machine.

~~~bash
docker cp <containerId>:/file/path/within/container /host/path/target

C:\Users\masandma\OneDrive - Microsoft\Desktop\myapp>docker cp oracle-xe1:/u01/app/oracle/microhack.lst .
Successfully copied 121kB to C:\Users\masandma\OneDrive - Microsoft\Desktop\myapp\.

~~~


