# Where to find Oracle scripts to support daily operations respectively for the following challenge


__[Useful Oracle online scripts](https://oracle-base.com/dba/scripts)__


~~~bash
SELECT name, value 
FROM V$PARAMETER
WHERE name='control_management_pack_access';

## The above query retrieves the name and value of the parameter 'control_management_pack_access' from the v$V$PARAMETER view in Oracle SQL.


select name, detected_usages, last_usage_date, last_sample_date
from dba_feature_usage_statistics
where name in (
    'ADDM', 'Automatic SQL Tuning Advisor', 'Automatic Workload Repository',
    'AWR Baseline', 'AWR Baseline Template', 'AWR Report', 'EM Performance Page',
    'Real-Time SQL Monitoring', 'SQL Access Advisor',
    'SQL Monitoring and Tuning pages', 'SQL Performance Analyzer',
    'SQL Tuning Advisor', 'SQL Tuning Set (system)', 'SQL Tuning Set (user)'
)
order by name;

## The above query retrieves the name, detected usages, last usage date, and last sample date of various features from the dba_feature_usage_statistics view in Oracle SQL.
~~~