-----------------------------------------------------------------------------
-- Select all namespaces (schemas) in the current database and order them by name
SELECT *
FROM pg_catalog.pg_namespace
ORDER BY nspname;

-----------------------------------------------------------------------------
-- Select the current user
SELECT CURRENT_USER;

-----------------------------------------------------------------------------
-- Select all active connections to a specific database
SELECT * 
FROM pg_stat_activity 
WHERE datname='database name';

-----------------------------------------------------------------------------
-- Terminate all active connections to the 'demo_schema' database, except for the current connection
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'demo_schema'
AND pid <> pg_backend_pid();

-----------------------------------------------------------------------------
-- List all databases
SELECT datname FROM pg_database;

-- list all tables in the schema demo_schema
-- pgsql> \dt
SELECT * FROM pg_catalog.pg_tables where schemaname like '%demo%';

-- Show Database size in MB
-- \l+ postgres
select pg_database_size('postgres')/1024/1024 as "DB Size in MB";

-----------------------------------------------------------------------------
-- Drop Schema in PostgreSQL if exists
DROP SCHEMA IF EXISTS demo_schema1 cascade;

-----------------------------------------------------------------------------
-- list extensions enabled in the current database
select * from pg_available_extensions where name like '%cron%' or name like '%crypto%'

-----------------------------------------------------------------------------
-- List all scheduled jobs
SELECT * FROM cron.job;

-- Delete a job by job name
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'data_generator_job';

-- Drop the job if it already exists
DO $$
BEGIN
    PERFORM cron.unschedule(jobid)
    FROM cron.job
    WHERE jobname = 'data_generator_job';
EXCEPTION
    WHEN OTHERS THEN
        -- Ignore the exception if the job does not exist
        IF SQLSTATE != '42704' THEN
            RAISE;
        END IF;
END $$;


-- Check the job schedule and last execution time
select * from cron.job_run_details;


-----------------------------------------------------------------------------
-- list all schema in postgresql database
-- pgsql> \dn
set search_path = demo_schema;

-- set search_path database wide
alter database postgres set search_path to demo_schema;

-- check the current/default schema
SHOW SEARCH_PATH;

--Change the default Schema at Session Level
SET SEARCH_PATH=newschema;

--Change the default schema at Database Level
ALTER DATABASE postgres SET search_path TO demo_schema;

--Change the default schema at User Level
-- ALTER ROLE|USER demo_schema SET search_path to <schema_name>;
ALTER ROLE|USER demo_schema SET search_path to demo_schema;


-----------------------------------------------------------------------------
-- Query to list all parameters with staged changes
SELECT name, setting, unit, source, pending_restart
FROM pg_settings


-----------------------------------------------------------------------------
-- Query for replication of oracle XE to postgresql flexible server
-- Connect to the PostgreSQL database as a superuser
psql -h microhack.postgres.database.azure.com -U postgres -d postgres

-- Grant necessary permissions to the demo_schema user
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE demo_schema.employees TO demo_schema;


-----------------------------------------------------------------------------
-- find duplicate rows in employees_audit table 
select employee_id, hire_date, count(*) from demo_schema.employees_audit group by employee_id, hire_date having count(*) > 1;

SELECT (demo_schema.employees_audit.*)::text, count(*) 
	from demo_schema.employees_audit group by demo_schema.employees_audit.*
	having count(*) > 1;