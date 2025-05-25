-- Data ingestion procedure to insert 1 million records into the employees table
-- Execute the procedure to ingest 1 million records
BEGIN
    ingest_1_million_records;
END;
/


-- Create the DBMS_SCHEDULER job
--BEGIN
    -- Drop the job if it already exists
--    BEGIN
--        DBMS_SCHEDULER.drop_job('demo_schema.transform_job');
--   EXCEPTION
--        WHEN OTHERS THEN
--            IF SQLCODE != -27475 THEN
--                RAISE;
--            END IF;
--    END;

    -- Create the job
--    DBMS_SCHEDULER.create_job (
--        job_name        => 'demo_schema.transform_job',
--        job_type        => 'PLSQL_BLOCK',
--        job_action      => 'BEGIN data_transform_pkg.transform_and_insert; END;',
--        start_date      => SYSTIMESTAMP,
--        repeat_interval => 'FREQ=SECONDLY; INTERVAL=5',
--        enabled         => TRUE
--    );
--END;
--/

