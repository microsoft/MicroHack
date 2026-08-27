 /*
 *	================
 *	MONITORING LAB 
 *	================

 *	The databases are hosted on:
 * 
 *						sqlhackmiXXXXX.database.windows.net
 *
 ************************************************************************************************************************************/


/************************************************************************************************************************************
 * PART 2:	USING [sys].[dm_exec_procedure_stats] TO EXAMINE EXECUTION STATS
 ************************************************************************************************************************************/
  
 --This query uses the [sys].[dm_exec_procedure_stats] DMV identify most consuming stored procedures and the details
 -- QUERY 1
select OBJECT_NAME(object_id,database_id) as ProcedureName
	,total_worker_time/1000 as total_worker_time_ms,min_worker_time/1000 as min_worker_time,max_worker_time/1000 as max_worker_time_ms,(total_worker_time/execution_count)/1000 as avg_worker_time_ms
	,total_elapsed_time/1000 as total_elapsed_time_ms,min_elapsed_time/1000 as min_elapsed_time_ms,max_elapsed_time/1000 as max_elapsed_time_ms,(total_elapsed_time/execution_count)/1000 as avg_execution_time_ms
	,total_logical_reads,min_logical_reads,max_logical_reads,(total_logical_reads/execution_count) as avg_logical_reads
	,total_physical_reads,min_physical_reads,max_physical_reads,(total_physical_reads/execution_count) as avg_physical_reads
	,total_logical_writes,min_logical_writes,max_logical_writes,(total_logical_writes/execution_count) as avg_logical_writes,type,cached_time,last_execution_time,execution_count
from sys.dm_exec_procedure_stats s
Where OBJECT_NAME(object_id,database_id) is not NULL
order by s.total_worker_time desc

-- QUERY 2 replace the filter clause with the SP identify
-- Procedure statement details
select OBJECT_NAME(object_id,database_id) as ProcedureName,st.text
,SUBSTRING(st.text, (qs.statement_start_offset/2)+1, 
((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)
ELSE qs.statement_end_offset
END - qs.statement_start_offset)/2) + 1) AS statement_text
,qp.query_plan
,qs.execution_count
,qs.total_worker_time,qs.min_worker_time,qs.max_worker_time,(qs.total_worker_time/qs.execution_count) as avg_worker_time
,qs.total_elapsed_time,qs.min_elapsed_time,qs.max_elapsed_time,(qs.total_elapsed_time/qs.execution_count) as avg_execution_time
,qs.total_logical_reads,qs.min_logical_reads,qs.max_logical_reads,(qs.total_logical_reads/qs.execution_count) as avg_logical_reads
,qs.total_physical_reads,qs.min_physical_reads,qs.max_physical_reads,(qs.total_physical_reads/qs.execution_count) as avg_physical_reads
,qs.total_logical_writes,qs.min_logical_writes,qs.max_logical_writes,(qs.total_logical_writes/qs.execution_count) as avg_logical_writes

,*
 from sys.dm_exec_procedure_stats ps
 left join sys.dm_exec_query_stats qs
 on ps.sql_handle=qs.sql_handle
  cross apply  sys.dm_exec_sql_text(qs.sql_handle) st
  cross apply sys.dm_exec_query_plan(qs.plan_handle) qp
where OBJECT_NAME(object_id,database_id) ='MyProc'  
 order by ProcedureName,qs.total_worker_time desc
/*
 * END PART 2 - RETURN TO LAB INSTRUCTIONS
 */

