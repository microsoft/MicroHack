REM ================================================================================
REM Name:       dbSizeCsv.sql
REM Type:       Oracle SQL script
REM Date:       05-12-2023
REM From:       Logicalis GmbH, Marcel Pils
REM
REM Description:
REM
REM     SQL for Oracle database size information used for Atroposs AWR module
REM
REM     requirements: read permissions on
REM                   dba_data_files, dba_free_space, dba_segments
REM                   dba_tables, dba_tab_partitions, dba_tab_subpartitions
REM     execution:    export ORACLE_HOME="xxxxx" ORACLE_SID="xxxxx"
REM                   exit | sqlplus -S / as sysdba @dbSizeCsv.sql
REM
REM Modifications:
REM     MPils   23feb23   v0.1    written
REM     MPils   06mar23   v0.2    fixed bytes to gb calculation
REM     MSandma 01oct23   v0.3    fixed calculation to gb
REM     MPils   05dec23   v0.4    added table compression
REM ================================================================================
--set termout off
set feedback off echo off time off timing off verify off
set trimspool on pagesize 0 linesize 500

column db_unique_name new_val db_unique_name for a30 noprint
select sys_context('USERENV','DB_UNIQUE_NAME') as db_unique_name from dual;

column output_file_name new_val output_file_name for a50 noprint
select '&db_unique_name.-dbSize.csv' as output_file_name from dual;

column ts new_val ts for a25 noprint
select to_char(sysdate, 'DD-MM-YYYY HH24:MI:SS') as ts from dual;

define V_B_RATIO="3"    -- compression ratio for BASIC/OLTP/ADVANCED
define V_QL_RATIO="6"   -- compression ratio for HCC QUERY LOW
define V_QH_RATIO="10"  -- compression ratio for HCC QUERY HIGH
define V_AL_RATIO="15"  -- compression ratio for HCC ARCHIVE LOW
define V_AH_RATIO="18"  -- compression ratio for HCC ARCHIVE HIGH

prompt Timestamp: &ts
prompt Output file: &output_file_name
prompt Running dbSizeCsv.sql on database &db_unique_name ...
prompt

spool &output_file_name

with datafiles as (
  /* get all data files */
  select  sum(d.bytes)/1073741824 as brutto_gb,
          sum(f.bytes)/1073741824 as free_gb,
          (sum(d.bytes)-sum(f.bytes))/1073741824 as netto_gb
  from    dba_data_files d
  inner join dba_free_space f on d.file_id = f.file_id
  where   d.tablespace_name not in ('SYSTEM','SYSAUX')
  and     d.tablespace_name not like '%UNDO%'
),
tables as (
  /* get TABLE, TABLE PARTITION and TABLE SUBPARTITION segments*/
  select
    sum(a.gb) as gb,
    sum(a.decomp_gb) as decomp_gb,
    sum(a.comp_cnt)+sum(a.nocomp_cnt) as tables,
    sum(a.nocomp_cnt) as nocomp_tables,
    sum(a.comp_cnt) as comp_tables,
    listagg(distinct
      a.compress_for ||
      decode(a.compress_for,null,null,'('||to_char(a.comp_for_tab_parts)||')'),
      ',') within group (order by a.compress_for) as comp_type_tables
  from (
    select b.*,
      sum(comp_cnt) over (partition by compress_for order by compress_for) as comp_for_tab_parts
    from (
      /* non partitioned tables */
      select   s.segment_type,
               t.table_name,
               null as partition_name,
               t.compression,
               t.compress_for,
               sum(s.bytes)/1073741824 as gb,
               decode(t.compression, 'ENABLED', -- decompressed gb
                      decode( 1,
                      regexp_instr(t.compress_for,'BASIC|OLTP|ADVANCED'), sum(s.bytes)*&&V_B_RATIO, -- BASIC compression
                      instr(t.compress_for,'QUERY LOW'), sum(s.bytes)*&&V_QL_RATIO,   -- HCC, QUERY LOW [ROW LEVEL LOCKING]
                      instr(t.compress_for,'QUERY HIGH'), sum(s.bytes)*&&V_QH_RATIO,  -- HCC, QUERY HIGH [ROW LEVEL LOCKING]
                      instr(t.compress_for,'ARCHIVE LOW'), sum(s.bytes)*&&V_AL_RATIO, -- HCC, ARCHIVE LOW [ROW LEVEL LOCKING]
                      instr(t.compress_for,'ARCHIVE HIGH'), sum(s.bytes)*&&V_AH_RATIO -- HCC, ARCHIVE HIGH [ROW LEVEL LOCKING]
                      ), sum(s.bytes)
                     )/1073741824 as decomp_gb,
               decode(t.compression, 'ENABLED',count(1),null) as comp_cnt,     -- compressed tables
               decode(t.compression, 'DISABLED',count(1),null) as nocomp_cnt   -- not compressed tables
      from     dba_tables t,
               dba_segments s
      where    s.segment_type = 'TABLE'
      and      t.partitioned = 'NO'             -- exclude partioned/subpartitioned tables
      and      s.owner = t.owner
      and      s.segment_name = t.table_name
      and      t.tablespace_name is not null
      and      t.tablespace_name not in ('SYSTEM','SYSAUX')
      and      t.tablespace_name not like '%UNDO%'
      -- and      t.table_name like 'TEST_TAB%'
      group by s.segment_type,
               t.table_name,
               t.compression,
               t.compress_for
      union all
      /* partitioned tables */
      select   s.segment_type,
               t.table_name,
               t.partition_name as partition_name,
               t.compression,
               t.compress_for,
               sum(s.bytes)/1073741824 as gb,
               decode(t.compression, 'ENABLED', -- decompressed gb
                      decode( 1,
                      regexp_instr(t.compress_for,'BASIC|OLTP|ADVANCED'), sum(s.bytes)*&&V_B_RATIO, -- BASIC compression
                      instr(t.compress_for,'QUERY LOW'), sum(s.bytes)*&&V_QL_RATIO,   -- HCC, QUERY LOW [ROW LEVEL LOCKING]
                      instr(t.compress_for,'QUERY HIGH'), sum(s.bytes)*&&V_QH_RATIO,  -- HCC, QUERY HIGH [ROW LEVEL LOCKING]
                      instr(t.compress_for,'ARCHIVE LOW'), sum(s.bytes)*&&V_AL_RATIO, -- HCC, ARCHIVE LOW [ROW LEVEL LOCKING]
                      instr(t.compress_for,'ARCHIVE HIGH'), sum(s.bytes)*&&V_AH_RATIO -- HCC, ARCHIVE HIGH [ROW LEVEL LOCKING]
                      ), sum(s.bytes)
                     )/1073741824 as decomp_gb,
               decode(t.compression, 'ENABLED',count(1)/count(1) over (order by table_name),null) as comp_cnt,    -- compressed table parts
               decode(t.compression, 'DISABLED',count(1)/count(1) over (order by table_name),null) as nocomp_cnt  -- not compressed table parts
      from     dba_tab_partitions t,
               dba_segments s
      where    s.segment_type = 'TABLE PARTITION'
      and      t.subpartition_count = 0   -- exclude partioned/subpartitioned tables
      and      s.owner = t.table_owner
      and      s.segment_name = t.table_name
      and      s.partition_name = t.partition_name
      and      t.tablespace_name is not null
      and      t.tablespace_name not in ('SYSTEM','SYSAUX')
      and      t.tablespace_name not like '%UNDO%'
      -- and      t.table_name like 'TEST_TAB%'
      group by s.segment_type,
               t.table_name,
               t.partition_name,
               t.compression,
               t.compress_for
      union all
      /* subpartitioned tables */
      select   s.segment_type,
               t.table_name,
               t.subpartition_name as partition_name,
               t.compression,
               t.compress_for,
               sum(s.bytes)/1073741824 as gb,
               decode(t.compression, 'ENABLED', -- decompressed gb
                      decode( 1,
                      regexp_instr(t.compress_for,'BASIC|OLTP|ADVANCED'), sum(s.bytes)*&&V_B_RATIO, -- BASIC compression
                      instr(t.compress_for,'QUERY LOW'), sum(s.bytes)*&&V_QL_RATIO,   -- HCC, QUERY LOW [ROW LEVEL LOCKING]
                      instr(t.compress_for,'QUERY HIGH'), sum(s.bytes)*&&V_QH_RATIO,  -- HCC, QUERY HIGH [ROW LEVEL LOCKING]
                      instr(t.compress_for,'ARCHIVE LOW'), sum(s.bytes)*&&V_AL_RATIO, -- HCC, ARCHIVE LOW [ROW LEVEL LOCKING]
                      instr(t.compress_for,'ARCHIVE HIGH'), sum(s.bytes)*&&V_AH_RATIO -- HCC, ARCHIVE HIGH [ROW LEVEL LOCKING]
                      ), sum(s.bytes)
                     )/1073741824 as decomp_gb,
               decode(t.compression, 'ENABLED',count(1)/count(1) over (order by table_name),null) as comp_cnt,    -- compressed table parts
               decode(t.compression, 'DISABLED',count(1)/count(1) over (order by table_name),null) as nocomp_cnt  -- not compressed table parts
      from     dba_tab_subpartitions t,
               dba_segments s
      where    s.segment_type = 'TABLE SUBPARTITION'
      and      s.owner = t.table_owner
      and      s.segment_name = t.table_name
      and      s.partition_name = t.subpartition_name
      and      t.tablespace_name is not null
      and      t.tablespace_name not in ('SYSTEM','SYSAUX')
      and      t.tablespace_name not like '%UNDO%'
      -- and      t.table_name like 'TEST_TAB%'
      group by s.segment_type,
               t.table_name,
               t.partition_name,
               t.subpartition_name,
               t.compression,
               t.compress_for
    ) b
  ) a
),
table_others as (
  /* other table based segment types
    compression thoughs:
    - whanted is: space requirements for uncompressed storage
    - what about lob compression?
  */
  select sum(bytes)/1073741824 as table_others_gb
  from   dba_segments
  where  segment_type in ('LOBSEGMENT','LOB PARTITION','LOB SUBPARTION','NESTED TABLE','CLUSTER')
  and    tablespace_name in (
           select tablespace_name from dba_data_files
           where  tablespace_name not in ('SYSTEM','SYSAUX')
           and    tablespace_name not like '%UNDO%'
         )
),
indexes as (
  /* get all indexes
    compression thoughs:
    - whanted is: space requirements for uncompressed storage
    - what about index compression?
  */
  select sum(bytes)/1073741824 as index_gb
  from   dba_segments
  where  segment_type in ('INDEX','INDEX PARTITION','INDEX SUBPARTITION','LOBINDEX')
  and    tablespace_name in (
           select tablespace_name from dba_data_files
           where  tablespace_name not in ('SYSTEM','SYSAUX')
           and    tablespace_name not like '%UNDO%'
         )
)
-- create csv output
select  'TS;DB_NAME;DB_UNAME;DF_BRUTTO_GB;DF_FREE_GB;DF_NETTO_GB;' ||
        'TABLE_GB;TABLE_DECOMP_GB;' ||
        'TABLES;NOCOMP_TABLES;COMP_TABLES;COMP_TYPE_TABLES;' ||
        'OTHER_GB;INDEX_GB;OBJ_BRUTTO_GB' as csv_header
from    dual
union all
select  to_char(sysdate,'DD.MM.YYYY HH24:MI:SS')                   -- TS
        ||';'|| sys_context('USERENV','DB_NAME')                   -- DB_NAME
        ||';'|| sys_context('USERENV','DB_UNIQUE_NAME')            -- DB_UNAME
        ||';'|| ceil(d.brutto_gb)                                  -- DF_BRUTTO_GB     round up to gb
        ||';'|| ceil(d.free_gb)                                    -- DF_FREE_GB       round up to gb
        ||';'|| ceil(d.netto_gb)                                   -- DF_NETTO_GB      round up to gb
        ||';'|| ceil(t.gb)                                         -- TABLE_GB         round up to gb
        ||';'|| ceil(t.decomp_gb)                                  -- TABLE_DECOMP_GB  round up to gb
        ||';'|| t.tables                                           -- TABLES
        ||';'|| t.nocomp_tables                                    -- NOCOMP_TABLES
        ||';'|| t.comp_tables                                      -- COMP_TABLES
        ||';'|| t.comp_type_tables                                 -- COMP_TYPE_TABLES
        ||';'|| ceil(o.table_others_gb)                            -- OTHER_GB         round up to gb
        ||';'|| ceil(i.index_gb)                                   -- INDEX_GB         round up to gb
        ||';'|| ceil(t.decomp_gb + o.table_others_gb + i.index_gb) -- OBJ_BRUTTO_GB    round up to gb
from    datafiles d,
        tables t,
        table_others o,
        indexes i
;
spool off
