SELECT
    DB_NAME(drs.database_id) AS DatabaseName,
    drs.synchronization_state_desc,
    drs.synchronization_health_desc,
    drs.is_commit_participant,
    drs.log_send_queue_size,
    drs.redo_queue_size,
    drs.last_commit_time
FROM sys.dm_hadr_database_replica_states drs
WHERE DB_NAME(drs.database_id) LIKE 'TEAM01%'
ORDER BY DatabaseName;