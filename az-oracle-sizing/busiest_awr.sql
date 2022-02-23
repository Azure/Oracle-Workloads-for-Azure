REM ================================================================================
REM Name:	busiest_awr.sql
REM Type:	Oracle SQL script
REM Date:	27-April 2020
REM From:	Americas Customer Engineering team (CET) - Microsoft
REM
REM Copyright and license:
REM
REM	Licensed under the Apache License, Version 2.0 (the "License"); you may
REM	not use this file except in compliance with the License.
REM
REM	You may obtain a copy of the License at
REM
REM		http://www.apache.org/licenses/LICENSE-2.0
REM
REM	Unless required by applicable law or agreed to in writing, software
REM	distributed under the License is distributed on an "AS IS" basis,
REM	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
REM
REM	See the License for the specific language governing permissions and
REM	limitations under the License.
REM
REM	Copyright (c) 2020 by Microsoft.  All rights reserved.
REM
REM Ownership and responsibility:
REM
REM	This script is offered without warranty by Microsoft Customer Engineering.
REM	Anyone using this script accepts full responsibility for use, effect,
REM	and maintenance.  Please do not contact Microsoft or Oracle support unless
REM	there is a problem with a supported SQL or SQL*Plus command.
REM
REM Description:
REM
REM	SQL*Plus script to find the top 5 busiest AWR snapshots within the horizon
REM	of all information stored within the Oracle AWR repository, based on the
REM	statistics "physical reads" (a.k.a. physical I/O or "PIO") and "CPU used
REM	by this session" (a.k.a. cumulative session-level CPU usage).
REM
REM Modifications:
REM	TGorman 27apr20 v0.1	written
REM	TGorman	04may20	v0.2	removed NTILE, using only ROW_NUMBER now...
REM	NBhandare 14May21 v0.3	added reference to innermost subqueries as fix for
REM				instance restart...
REM	TGorman	01jun21	v0.4	cleaned up some mistakes, parameterized 
REM ================================================================================
set pages 100 lines 80 verify off echo off feedback 6 timing off recsep off
col dbid heading 'DB ID'
col con_id format 90 heading 'Con|ID'
col instance_number format 90 heading 'I#'
col snap_id heading 'AWR|Snap ID'
col begin_tm format a20 heading 'Beginning|time' word_wrap
col end_tm format a20 heading 'Ending|time' word_wrap
col pio heading 'Physical|Reads|(PIO)'
col cpu heading 'CPU used by|this session|(CPU)'
define V_BUCKETS=98		/* only retain values from 98th percentile or below */
define V_CPU_FACTOR=1		/* multiplicative factor to favor/disfavor CPU metrics */
define V_PIO_FACTOR=5		/* multiplicative factor to favor/disfavor I/O metrics */
spool busiest_awr
select	x.instance_number,
	x.snap_id,
	to_char(s.begin_interval_time, 'DD-MON-YYYY HH24:MI:SS') begin_tm,
	to_char(s.end_interval_time, 'DD-MON-YYYY HH24:MI:SS') end_tm,
	x.pio,
	x.cpu
from	(select	instance_number, snap_id, pio, cpu, row_number() over (partition by instance_number order by sortby desc) rn
	 from	(select	instance_number, snap_id,
		 	sum(pio) pio, sum(cpu) cpu, avg(sortby) sortby
		 from	(select	instance_number, snap_id, pio, cpu, sortby
			 from	(select instance_number, snap_id, value pio, 0 cpu, (value*(&&V_PIO_FACTOR)) sortby,
					ntile(100) over (partition by instance_number order by value) bucket
				 from	(select	s.instance_number, s.snap_id,
						nvl(decode(greatest(value, nvl(lag(value) over (partition by h.startup_time, s.instance_number order by s.snap_id),0)),
							value, value - lag(value) over (partition by h.startup_time, s.instance_number order by s.snap_id), value), 0) value
					 from	dba_hist_sysstat s, dba_hist_snapshot h
					 where	stat_name = 'physical reads'
					 and	s.dbid = (select dbid from v$database)
					 and	h.dbid = s.dbid
					 and	h.instance_number = s.instance_number
					 and	h.snap_id = s.snap_id)
				 union all
				 select	instance_number, snap_id, 0 pio, value cpu, (value*(&&V_CPU_FACTOR)) sortby,
					ntile(100) over (partition by instance_number order by value) bucket
				 from	(select	s.instance_number, s.snap_id,
						nvl(decode(greatest(value, nvl(lag(value) over (partition by h.startup_time, s.instance_number order by s.snap_id),0)),
							value, value - lag(value) over (partition by h.startup_time, s.instance_number order by s.snap_id), value), 0) value
					 from	dba_hist_sysstat s, dba_hist_snapshot h
					 where	stat_name = 'CPU used by this session'
					 and	s.dbid = (select dbid from v$database)
					 and	h.dbid = s.dbid
					 and	h.instance_number = s.instance_number
					 and	h.snap_id = s.snap_id))
			 where bucket <= &&V_BUCKETS)
	 group by instance_number, snap_id)) x,
	dba_hist_snapshot s
where	s.snap_id = x.snap_id
and	s.instance_number = x.instance_number
and	rn <= 5
order by rn, instance_number;
spool off
