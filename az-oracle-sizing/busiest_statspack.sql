REM ================================================================================
REM Name:       busiest_statspack.sql
REM Type:       Oracle SQL script
REM Date:       27-April 2020
REM From:       Americas Customer Success team (CSU) - Microsoft
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
REM     SQL*Plus script to find the top 5 busiest STATSPACK snapshots within the horizon
REM     of all information stored within the Oracle STATSPACK repository, based on the
REM     STATSPACK statistic "CPU used by this session" and the two I/O statistics
REM     "physical reads" and "physical writes", all residing within the STATSPACK
REM     table named STATS$SYSSTAT, populated from the view V$SYSSTAT.
REM
REM Modifications:
REM     TGorman 09jan23 v0.6    copied from script "busiest_awr.sql" v0.6
REM ================================================================================
set pages 100 lines 180 verify off echo off feedback 6 timing off recsep off
col instance_number format 90 heading 'I#'
col snap_id heading 'Beginning|Snap ID'
col begin_tm format a20 heading 'Beginning|Snap Time' word_wrap
col avg_value heading 'Average|IO and CPU|per second' format 999,999,990.0000
define V_CPU_WEIGHT=1           /* multiplicative factor to favor/disfavor CPU metrics */
define V_IO_WEIGHT=2            /* multiplicative factor to favor/disfavor I/O metrics */
spool b
select  x.instance_number,
        x.snap_id snap_id,
        to_char(s.end_interval_time, 'DD-MON-YYYY HH24:MI:SS') begin_tm,
        x.avg_value
from    (select instance_number, snap_id, avg_value,
                row_number() over (partition by instance_number order by avg_sort_value desc) rn
         from   (select instance_number, snap_id, avg(value) avg_value, avg(sort_value) avg_sort_value
                 from   (select instance_number, snap_id, sum(value)-sum(lag_value) value, ((sum(value)-sum(lag_value))*&&V_CPU_WEIGHT) sort_value
                         from   (select instance_number, snap_id, value, lag(value) over (partition by instance_number order by snap_id) lag_value
                                 from   stats$sysstat
                                 where  name in ('CPU used by this session')
                                 and    dbid = (select dbid from v$database))
                         where  lag_value is not null
                         group by instance_number, snap_id
                         union all
                         select instance_number, snap_id, sum(value)-sum(lag_value) value, ((sum(value)-sum(lag_value))*&&V_IO_WEIGHT) sort_value
                         from   (select instance_number, snap_id, value, lag(value) over (partition by instance_number, name order by snap_id) lag_value
                                 from   stats$sysstat
                                 where  name in ('physical reads','physical writes')
                                 and    dbid = (select dbid from v$database))
                         where  lag_value is not null
                         group by instance_number, snap_id)
                 group by instance_number, snap_id)) x,
        dba_hist_snapshot s
where   s.snap_id = x.snap_id
and     s.instance_number = x.instance_number
and     s.dbid = (select dbid from v$database)
and     x.rn <= 5
order by instance_number, rn;
spool off
