The following section explain how to create an oracle AWR (Automatic Workload Repository Report). Please verify what kind of licenses are available before creating an AWR because the creation required an appropriate Oracle license!

For enterprise editions without the required license statspack report need to be created as well.

Please clarify internal if your licenses or contract with kind of report can be used


# Create / Generate an AWR report for discovery purposes

For demo purposes we can download an AWR example from the internet.

~~~bash
curl -o awr_report.html https://www.oracle.com/a/ocom/docs/applications/ebusiness/awrrpt-1-659-667-o-to-c-batch.html
~~~


# Grant the Necessary Privileges
Grant the SELECT_CATALOG_ROLE to the user ouser3 to allow access to the DBA_HIST_SNAPSHOT view.

~~~bash
GRANT SELECT_CATALOG_ROLE TO ouser3;
GRANT EXECUTE ON DBMS_WORKLOAD_REPOSITORY TO ouser3;
~~~

# Determine the Snapshot IDs / available procedures in package AWR

~~~bash
SELECT SNAP_ID, BEGIN_INTERVAL_TIME, END_INTERVAL_TIME
FROM DBA_HIST_SNAPSHOT
ORDER BY SNAP_ID;

SELECT OBJECT_NAME, PROCEDURE_NAME
FROM ALL_PROCEDURES
WHERE OBJECT_NAME = 'DBMS_WORKLOAD_REPOSITORY';

-- Generate AWR report in HTML format
SET LONG 1000000
SET PAGESIZE 0
SET LINESIZE 200
SPOOL awr_report.html
SELECT * FROM TABLE(DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_HTML(
  l_dbid            => (SELECT dbid FROM v$database),
  l_inst_num        => (SELECT instance_number FROM v$instance),
  l_bid             => start_no,  -- Replace with the actual begin snapshot ID
  l_eid             => end_no   -- Replace with the actual end snapshot ID
));
SPOOL OFF
~~~

# Generate the AWR report

[Global AWR Reports for cluster](https://support.oracle.com/epmos/faces/DocumentDisplay?_afrLoop=66796970861713&id=2089139.1&_afrWindowMode=0&_adf.ctrl-state=jzkmn90ik_4)

[How to generate AWR /ADDM /ASH](https://support.oracle.com/epmos/faces/DocumentDisplay?_afrLoop=67272757096652&id=2349082.1&displayIndex=3&_afrWindowMode=0&_adf.ctrl-state=jzkmn90ik_222#GOAL)

