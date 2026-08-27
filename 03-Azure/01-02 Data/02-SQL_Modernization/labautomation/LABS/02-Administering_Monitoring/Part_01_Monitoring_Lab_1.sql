/************************************************************************************************************************************
 *
 *	================
 *	MONITORING LAB 
 *	================

 *	The databases are hosted on:
 * 
 *						sqlhackmiXXXXX.database.windows.net
 *
 ************************************************************************************************************************************/




/************************************************************************************************************************************
 * PART 1: USING [sys].[dm_db_resource_stats] DMV TO LOOK AT THE SQL MI RESOURCES STATS
 ************************************************************************************************************************************/
 
--QUERY 1
SELECT * FROM sys.dm_db_resource_stats ; -- measure each 15 seconds over 1h
/*
 * Note the [avg_cpu_percent] is above 80% indicating that the CPU could be under pressure.
 */
--QUERY 2
SELECT end_time,avg_cpu_percent,avg_data_io_percent FROM sys.dm_db_resource_stats  order by end_time asc; 

-- QUERY 3
-- For a wide historic up to 14 days
select start_time,avg_cpu_percent,io_requests,* from sys.server_resource_stats  

/*
 * END PART 1 - RETURN TO LAB INSTRUCTIONS
 */

