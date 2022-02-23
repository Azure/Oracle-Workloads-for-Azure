/*********************************************************************************
 * File:        dbspace.sql
 * Type:        Oracle SQL*Plus script
 * Date:        26-Aug 2020
 * Author:      Microsoft Customer Architecture & Engineering (CAE)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Copyright (c) 2020 by Microsoft. All rights reserved.
 *
 * Description:
 *
 *      Oracle SQL*Plus script to display summary information about the size of an
 *      Oracle database, summarizing datafiles, tempfiles, controlfiles, online
 *      redo log files, and block change tracking files.  Also summarizes backups
 *      of datafiles and archived redo log files.
 *
 *      Output is spooled to the present working directory to a file named
 *      "dbspace_<DB-NAME>.lst", where "DB-NAME" is the database name.
 *
 * Modifications:
 *      TGorman 26-Aug 2020     v1.0 - written
 *      TGorman 03-Sep 2020     v1.1 - added SQL*Plus "set" for formatting
 *      TGorman 30-Nov 2020     v1.2 - added queries on V$LOG/V$LOGFILE for redo
 *                                     group/member info
 *      TGorman 30-Nov 2020     v1.3 - added query with HCC recompression calcs
 ********************************************************************************/
set echo off feedback off timing off pagesize 100 linesize 130 trimout on trimspool on verify off
define V_AH_RATIO="18"  -- compression ratio for ARCHIVE HIGH
define V_AL_RATIO="15"  -- compression ratio for ARCHIVE LOW
define V_QH_RATIO="10"  -- compression ratio for QUERY HIGH
define V_QL_RATIO="6"   -- compression ratio for QUERY LOW
define V_B_RATIO="3"    -- compression ratio for BASIC/OLTP/ADVANCED
col name new_value V_DBNAME noprint
select name from v$database;
set feedback on
spool dbspace_&&V_DBNAME
clear breaks computes
break on report
compute sum of mb on report
col type format a10 heading "File type"
col mb format 999,999,990.00 heading "DB Size (MB)"
select  type, sum(bytes)/1048576 mb
from    (select 'Datafile' type, bytes from dba_data_files
         union all
         select 'Tempfile' type, bytes from dba_temp_files
         union all
         select 'OnlineRedo' type, bytes*members bytes from v$log
         union all
         select 'Ctlfile' type, file_size_blks*block_size bytes from v$controlfile
         union all
         select 'BCTfile' type, nvl(bytes,0) bytes from v$block_change_tracking)
group by type
order by type;

col segment_type heading "Segment Type"
col compression heading "Enabled?"
col compress_for heading "Compression Type"
col rw_ro format a9 heading "Read-Only?"
col mb format 999,999,990.00 heading "Seg Size (MB)"
col recompressed_mb format 999,999,990.00 heading "Addl MB after|Recompression"
col cnt format 999,990 heading "# Segs"
clear breaks computes
break on segment_type on compression on compress_for on rw_ro on report
compute sum of mb on report
compute sum of recompressed_mb on report
compute sum of cnt on report
select  s.segment_type,
        t.compression,
        t.compress_for,
        decode(x.status, 'ONLINE', null, x.status) rw_ro,
        sum(s.bytes)/1048576 mb,
        decode(t.compression,
                'ENABLED', decode(t.compress_for,
                                'ARCHIVE LOW', (((sum(s.bytes)*&&V_AL_RATIO)/&&V_B_RATIO)-sum(s.bytes)),
                                'ARCHIVE HIGH', (((sum(s.bytes)*&&V_AH_RATIO)/&&V_B_RATIO)-sum(s.bytes)),
                                'QUERY LOW', (((sum(s.bytes)*&&V_QL_RATIO)/&&V_B_RATIO)-sum(s.bytes)),
                                'QUERY HIGH', (((sum(s.bytes)*&&V_QH_RATIO)/&&V_B_RATIO)-sum(s.bytes)))/1048576) recompressed_mb,
        count(*) cnt
from    dba_tables t,
        dba_segments s,
        dba_tablespaces x
where   t.partitioned = 'NO'
and     t.tablespace_name is not null
and     s.segment_type = 'TABLE'
and     s.owner = t.owner
and     s.segment_name = t.table_name
and     x.tablespace_name = s.tablespace_name
group by s.segment_type,
         t.compression,
         t.compress_for,
         decode(x.status, 'ONLINE', null, x.status)
union all
select  s.segment_type,
        t.compression,
        t.compress_for,
        decode(x.status, 'ONLINE', null, x.status) rw_ro,
        sum(s.bytes)/1048576 mb,
        decode(t.compression,
                'ENABLED', decode(t.compress_for,
                                'ARCHIVE LOW', (((sum(s.bytes)*&&V_AL_RATIO)/&&V_B_RATIO)-sum(s.bytes)),
                                'ARCHIVE HIGH', (((sum(s.bytes)*&&V_AH_RATIO)/&&V_B_RATIO)-sum(s.bytes)),
                                'QUERY LOW', (((sum(s.bytes)*&&V_QL_RATIO)/&&V_B_RATIO)-sum(s.bytes)),
                                'QUERY HIGH', (((sum(s.bytes)*&&V_QH_RATIO)/&&V_B_RATIO)-sum(s.bytes)))/1048576) recompressed_mb,
        count(*) cnt
from    dba_tab_partitions t,
        dba_segments s,
        dba_tablespaces x
where   t.subpartition_count = 0
and     t.tablespace_name is not null
and     s.segment_type = 'TABLE PARTITION'
and     s.owner = t.table_owner
and     s.segment_name = t.table_name
and     s.partition_name = t.partition_name
and     x.tablespace_name = s.tablespace_name
group by s.segment_type,
         t.compression,
         t.compress_for,
         decode(x.status, 'ONLINE', null, x.status)
union all
select  s.segment_type,
        t.compression,
        t.compress_for,
        decode(x.status, 'ONLINE', null, x.status) rw_ro,
        sum(s.bytes)/1048576 mb,
        decode(t.compression,
                'ENABLED', decode(t.compress_for,
                                'ARCHIVE LOW', (((sum(s.bytes)*&&V_AL_RATIO)/&&V_B_RATIO)-sum(s.bytes)),
                                'ARCHIVE HIGH', (((sum(s.bytes)*&&V_AH_RATIO)/&&V_B_RATIO)-sum(s.bytes)),
                                'QUERY LOW', (((sum(s.bytes)*&&V_QL_RATIO)/&&V_B_RATIO)-sum(s.bytes)),
                                'QUERY HIGH', (((sum(s.bytes)*&&V_QH_RATIO)/&&V_B_RATIO)-sum(s.bytes)))/1048576) recompressed_mb,
        count(*) cnt
from    dba_tab_subpartitions t,
        dba_segments s,
        dba_tablespaces x
where   t.tablespace_name is not null
and     s.segment_type = 'TABLE SUBPARTITION'
and     s.owner = t.table_owner
and     s.segment_name = t.table_name
and     s.partition_name = t.subpartition_name
and     x.tablespace_name = s.tablespace_name
group by s.segment_type,
         t.compression,
         t.compress_for,
         decode(x.status, 'ONLINE', null, x.status)
order by 1, 2, 3, 4, 5 desc;

clear breaks computes
break on thread# on group# on members on report
col thread# heading "Thread"
col group# heading "Group"
col members heading "Members"
col mb format 999,999,990.00 heading "Member Size (MB)"
compute sum of mb on report
select  thread#,
        group#,
        members,
        max(bytes)/1048576 mb
from    v$log
group by thread#,
         group#,
         members
order by 1, 2, 3;

col sort0 noprint
col dbf_mb format 999,999,999,990.00 heading "Source|database|files (MB)"
col day heading "Day"
col backup_type format a4 heading "Bkup|Type"
col incremental_level format 9990 heading "Incr|Lvl"
col read_mb format 999,999,999,990.00 heading "Backup|read|(MB)"
col bkp_mb format 999,999,999,990.00 heading "Database file|backup written|(MB)"
clear breaks computes
break on day on report
compute sum of dbf_mb on report
compute sum of read_mb on report
compute sum of bkp_mb on report
select  to_char(f.completion_time,'YYYYMMDD') sort0,
        to_char(f.completion_time,'DD-MON-YYYY') day,
        s.backup_type,
        s.incremental_level,
        sum(f.datafile_blocks*f.block_size)/1048576 dbf_mb,
        sum(f.blocks_read*f.block_size)/1048576 read_mb,
        sum(f.blocks*f.block_size)/1048576 bkp_mb
from    v$backup_datafile       f,
        v$backup_set            s
where   s.set_stamp = f.set_stamp
and     s.set_count = f.set_count
group by to_char(f.completion_time,'YYYYMMDD'),
         to_char(f.completion_time,'DD-MON-YYYY'),
         s.backup_type,
         s.incremental_level
order by sort0;

clear breaks computes
break on day on report
compute avg of mb on report
compute sum of mb on report
col sort0 noprint
col day heading "Day"
col mb format 999,999,990.00 heading "Archived|redo Size (MB)"
select  to_char(next_time,'YYYYMMDD') sort0,
        to_char(next_time,'DD-MON-YYYY') day,
        sum(blocks*block_size)/1048576 mb
from    v$archived_log
group by to_char(next_time,'YYYYMMDD'),
         to_char(next_time,'DD-MON-YYYY')
order by sort0;

clear breaks computes
break on day on report
compute sum of mb on report
col bkp_mb format 999,999,990.00 heading "Archived redo|backup written|(MB)"
select  to_char(next_time,'YYYYMMDD') sort0,
        to_char(next_time,'DD-MON-YYYY') day,
        sum(blocks*block_size)/1048576 bkp_mb
from    v$backup_redolog
group by to_char(next_time,'YYYYMMDD'),
         to_char(next_time,'DD-MON-YYYY')
order by sort0;

clear breaks computes
spool off
