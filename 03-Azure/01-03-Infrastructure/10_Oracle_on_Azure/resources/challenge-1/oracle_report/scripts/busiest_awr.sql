REM ================================================================================
REM Name:       busiest_awr.sql
REM Type:       Oracle SQL script
REM Date:       27-April 2020
REM From:       Americas Customer Engineering team (CET) - Microsoft
REM
REM Copyright and license:
REM
REM     Licensed under the Apache License, Version 2.0 (the "License"); you may
REM     not use this file except in compliance with the License.
REM
REM     You may obtain a copy of the License at
REM
REM             http://www.apache.org/licenses/LICENSE-2.0
REM
REM     Unless required by applicable law or agreed to in writing, software
REM     distributed under the License is distributed on an "AS IS" basis,
REM     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
REM
REM     See the License for the specific language governing permissions and
REM     limitations under the License.
REM
REM     Copyright (c) 2020 by Microsoft.  All rights reserved.
REM
REM Ownership and responsibility:
REM
REM     This script is offered without warranty by Microsoft Customer Engineering.
REM     Anyone using this script accepts full responsibility for use, effect,
REM     and maintenance.  Please do not contact Microsoft or Oracle support unless
REM     there is a problem with a supported SQL or SQL*Plus command.
REM
REM Description:
REM
REM     SQL*Plus script to find the top 5 busiest AWR snapshots within the horizon
REM     of all information stored within the Oracle AWR repository, based on the
REM     AWR metrics "CPU Usage Per Sec" and "I/O Megabytes per Second" found in the
REM     view DBA_HIST_SYSMETRIC_HISTORY.
REM
REM     execution:  export ORACLE_HOME="xxxxx" ORACLE_SID="xxxxx"
REM                 exit | sqlplus -S / as sysdba @busiest_awr.sql
REM
REM Modifications:
REM     TGorman   27apr20 v0.1    written
REM     TGorman   04may20 v0.2    removed NTILE, using only ROW_NUMBER now...
REM     NBhandare 14May21 v0.3    added reference to innermost subqueries as fix for
REM                               instance restart...
REM     TGorman   01jun21 v0.4    cleaned up some mistakes, parameterized
REM     TGorman   09dec22 v0.5    changed query from using stats from DBA_HIST_SYSSTAT
REM                               to using metrics from DBA_HIST_SYSMETRIC_HISTORY
REM     TGorman   12dec22 v0.6    cleaned up snap IDs and times
REM     MPils     23feb23 v0.6.1  changed spool filename and added execution description
REM ================================================================================
set feedback off echo off feedback 6 time off timing off verify off
set recsep off trimspool on pagesize 100 linesize 180

define V_CPU_WEIGHT=1           /* multiplicative factor to favor/disfavor CPU metrics */
define V_IO_WEIGHT=2            /* multiplicative factor to favor/disfavor I/O metrics */

col instance_number format 90 heading 'I#'
col snap_id heading 'Beginning|Snap ID'
col begin_tm format a20 heading 'Beginning|Snap Time' word_wrap
col avg_value heading 'Average|IO and CPU|per second' format 999,999,990.0000

column db_unique_name new_val db_unique_name for a30 noprint
select sys_context('USERENV','DB_UNIQUE_NAME') as db_unique_name from dual;

column output_file_name new_val output_file_name for a50 noprint
select '&db_unique_name.-busiest_awr.out' as output_file_name from dual;

column ts new_val ts for a25 noprint
select to_char(sysdate, 'DD-MM-YYYY HH24:MI:SS') as ts from dual;

spool &output_file_name

prompt Timestamp: &ts
prompt Output file: &output_file_name
prompt Running busiest_awr.sql on database &db_unique_name ...
prompt Display top 5 busiest AWR snapshots

select  x.instance_number,
        x.snap_id snap_id,
        to_char(s.end_interval_time, 'DD-MON-YYYY HH24:MI:SS') begin_tm,
        x.avg_value
from    (select instance_number, snap_id, avg(value) avg_value, avg(sort_value) sort_value,
                row_number() over (partition by instance_number order by avg(sort_value) desc) rn
         from   (select instance_number, snap_id, value, (value*&&V_CPU_WEIGHT) sort_value
                 from   dba_hist_sysmetric_history
                 where  metric_name = 'CPU Usage Per Sec'
                 and    dbid = (select dbid from v$database)
                 union all
                 select instance_number, snap_id, value, (value*&&V_IO_WEIGHT) sort_value
                 from   dba_hist_sysmetric_history
                 where  metric_name = 'I/O Megabytes per Second'
                 and    dbid = (select dbid from v$database))
         group by instance_number, snap_id) x,
        dba_hist_snapshot s
where   s.snap_id = x.snap_id
and     s.instance_number = x.instance_number
and     rn <= 5
order by instance_number, rn;
spool off
