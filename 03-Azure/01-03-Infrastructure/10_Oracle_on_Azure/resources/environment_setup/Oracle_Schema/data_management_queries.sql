
--------------------------------------------------------------------------------------------------------------------------------------------------------------

-- This script is used to clean up and reset the schema 'demo_schema' under the user 'system' or 'sys'.
-- It deletes all objects in the specified schema and removes existing scheduled jobs.

-- Enable server output to display messages
SET SERVEROUTPUT ON SIZE 1000000
-- Disable variable substitution verification
set verify off


-- Begin PL/SQL block to delete all objects in the specified schema
BEGIN
    -- Loop through all referential constraints in the specified schema and drop them
    FOR c1 IN (SELECT OWNER,table_name, constraint_name 
        FROM dba_constraints 
        WHERE constraint_type = 'R' and owner=upper('&shema_name')) LOOP
    EXECUTE IMMEDIATE 'ALTER TABLE '||' "'||c1.owner||'"."'||c1.table_name||'" DROP CONSTRAINT ' || c1.constraint_name;
END LOOP;
-- Loop through all referential constraints in the specified schema and drop them
FOR c1 IN (SELECT owner,object_name,object_type 
        FROM dba_objects 
        where owner=upper('&shema_name')) LOOP
    BEGIN
    -- Drop TYPE objects with FORCE option
    IF c1.object_type = 'TYPE' THEN
        EXECUTE IMMEDIATE 'DROP '||c1.object_type||' "'||c1.owner||'"."'||c1.object_name||'" FORCE';
    END IF;

    -- Drop all other objects except DATABASE LINK
    IF c1.object_type != 'DATABASE LINK' THEN
        EXECUTE IMMEDIATE 'DROP '||c1.object_type||' "'||c1.owner||'"."'||c1.object_name||'"';
    END IF;
EXCEPTION
        -- Ignore any errors that occur during the drop operations
        WHEN OTHERS THEN
            NULL;
END;
END LOOP;
-- Purge the recycle bin to permanently remove dropped objects
EXECUTE IMMEDIATE('purge dba_recyclebin');
END;
/


-- In a second step delete existing job in user schema demo_schema
begin dbms_scheduler.drop_job(job_name => 'TRANSFORM_JOB');
end;
/

-- In a second step delete existing job in user schema demo_schema
begin dbms_scheduler.drop_job(job_name => 'DATA_GENERATOR_JOB');
end;
/

-- Select and display information about all scheduler jobs in the 'demo_schema'
select owner, JOB_NAME, LAST_START_DATE, NEXT_RUN_DATE 
from all_scheduler_jobs 
where owner = 'DEMO_SCHEMA';


--------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Example queries to retrieve information about the database and its objects
-- Calculate total size for database objects
SELECT 
( SELECT SUM(BYTES)/1024/1024/1024/1024 DATA_SIZE FROM DBA_DATA_FILES ) +
( SELECT NVL(SUM(BYTES),0)/1024/1024/1024/1024 TEMP_SIZE FROM DBA_TEMP_FILES ) +
( SELECT SUM(BYTES)/1024/1024/1024/1024 REDO_SIZE FROM SYS.V_$LOG ) +
( SELECT SUM(BLOCK_SIZE*FILE_SIZE_BLKS)/1024/1024/1024/1024 CONTROLFILE_SIZE FROM V$CONTROLFILE) "SIZE IN TB"
FROM
DUAL;

-- Query below returns changed columns of all data in audit_log of the database
select operation, cast(audit_log.old_values as varchar2(2000)) as old_values,  cast(audit_log.new_values as varchar2(2000)) as new_values from Audit_log;


