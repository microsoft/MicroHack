----------------------------------------------------------------------------------------------------------------------------------------------------------
-- Execute manual the procedure data_generator to insert, update, and delete data records
--BEGIN
--    data_generator;
--END;
--/

-- Schedule the data_generator procedure to run every 2 minutes
BEGIN
    -- Drop the job if it already exists
    BEGIN
        DBMS_SCHEDULER.drop_job('demo_schema.data_generator_job');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -27475 THEN
                RAISE;
            END IF;
    END;

    -- Create the job data_generator_job
    DBMS_SCHEDULER.create_job (
        job_name        => 'demo_schema.data_generator_job',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN data_generator; END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=MINUTELY; INTERVAL=2', -- Run every 2 minutes
        enabled         => TRUE
    );
END;
/