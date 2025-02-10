-- Schedule the data_generator procedure to run every 2 minutes
SELECT cron.schedule(
    'data_generator_job',  -- Job name
    '*/2 * * * *',         -- Cron expression to run every 2 minutes
    $$CALL demo_schema.data_generator();$$  -- Job action
);



-- Execute the procedure data_generator to insert, update, and delete data records
-- CALL data_generator();