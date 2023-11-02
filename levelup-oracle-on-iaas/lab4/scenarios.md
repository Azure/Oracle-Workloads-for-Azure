# Scenarios for testing Data guard setup

## Verify the configuration

### Login to the observer

```powershell
#Login to the Observer 
$ ssh <adminusername>@<observerpublicip>
Enter passphrase for key '/home/adminusername/.ssh/id_rsa':
Last login: Sat Oct 14 15:10:45 2023 from 49.205.86.40
[adminusername@observer ~]$ sudo su - oracle
Last login: Sat Oct 14 15:10:51 UTC 2023 on pts/0
[oracle@observer ~]$ export ORACLE_SID=oradb01_dgmgrl
```

### Launch the Data guard managment command line utility (DGMGRL) with Primary SID

```powershell
[oracle@observer ~]$ dgmgrl sys/oracleA1@oradb01_dgmgrl
DGMGRL for Linux: Release 19.0.0.0.0 - Production on Sat Oct 14 15:23:02 2023
Version 19.3.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

Welcome to DGMGRL, type "help" for information.
Connected to "oradb01"
Connected as SYSDBA.
DGMGRL>
```
### Show the configuration

```powershell
DGMGRL> show configuration;

Configuration - FSF

  Protection Mode: MaxAvailability
  Members:
  oradb01 - Primary database
    oradb02 - (*) Physical standby database

Fast-Start Failover: Enabled in Zero Data Loss Mode

Configuration Status:
SUCCESS   (status updated 26 seconds ago)

DGMGRL>
```

The output should be similar to the above, with FSFO setup and Protection mode in Maximum Availability

## Validate if the secondary database is ready for Switchover.

A switchover is a role reversal between the primary database and one of its standby databases. A switchover guarantees no data loss and is typically done for planned maintenance of the primary system. During a switchover, the primary database transitions to a standby role, and the standby database transitions to the primary role. 

[Oracle documentation](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/using-data-guard-broker-to-manage-switchovers-failovers.html#GUID-7F6C5802-E4AF-4680-91F6-AD380679A555)

### Verify if the Standby database is ready for switch over

In the same DGMGRL
```powershell
DGMGRL> validate database oradb02;

  Database Role:     Physical standby database
  Primary Database:  oradb01

  Ready for Switchover:  Yes
  Ready for Failover:    Yes (Primary Running)

  Managed by Clusterware:
    oradb01:  NO
    oradb02:  NO
    Validating static connect identifier for the primary database oradb01...
    The static connect identifier allows for a connection to database "oradb01".

  Log Files Cleared:
    oradb01 Standby Redo Log Files:  Cleared
    oradb02 Online Redo Log Files:   Not Cleared
    oradb02 Standby Redo Log Files:  Available

  Current Log File Groups Configuration:
    Thread #  Online Redo Log Groups  Standby Redo Log Groups Status
              (oradb01)               (oradb02)
    1         3                       2                       Insufficient SRLs

  Future Log File Groups Configuration:
    Thread #  Online Redo Log Groups  Standby Redo Log Groups Status
              (oradb02)               (oradb01)
    1         3                       0                       Insufficient SRLs
    Warning: standby redo logs not configured for thread 1 on oradb01

DGMGRL>
```

## Switch over to Secondary database using Data guard command line

```powershell
DGMGRL> switchover to oradb02;
Performing switchover NOW, please wait...
Operation requires a connection to database "oradb02"
Connecting ...
Connected to "oradb02"
Connected as SYSDBA.
New primary database "oradb02" is opening...
Operation requires start up of instance "oradb01" on database "oradb01"
Starting instance "oradb01"...
Connected to an idle instance.
ORACLE instance started.
Connected to "oradb01"
Database mounted.
Database opened.
Connected to "oradb01"
Switchover succeeded, new primary is "oradb02"
DGMGRL>
```
## Switch Back to Primary database

```powershell
DGMGRL> switchover to oradb01;
Performing switchover NOW, please wait...
Operation requires a connection to database "oradb01"
Connecting ...
Connected to "oradb01"
Connected as SYSDBA.
New primary database "oradb01" is opening...
Operation requires start up of instance "oradb02" on database "oradb02"
Starting instance "oradb02"...
Connected to an idle instance.
ORACLE instance started.
Connected to "oradb02"
Database mounted.
Database opened.
Connected to "oradb02"
Switchover succeeded, new primary is "oradb01"
DGMGRL>
```

## Initiate a (controlled) failover to Secondary through Data Guard command line 

A failover is a role transition in which one of the standby databases is transitioned to the primary role after the primary database (all instances in the case of an Oracle RAC database) fails or has become unreachable. A failover may or may not result in data loss depending on the protection mode in effect at the time of the failover. 

[Oracle documentation](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/using-data-guard-broker-to-manage-switchovers-failovers.html#GUID-7F6C5802-E4AF-4680-91F6-AD380679A555)

Login to the Observer, sudo to Oracle account,  connect to Data guard command line to the Standby SID.

```powershell
$ ssh <adminusername>@<observerip>
Enter passphrase for key '/home/<adminusername>/.ssh/id_rsa':
Last login: Sun Oct 15 11:15:37 2023 from 49.204.116.157
[<adminusername>@observer ~]$ sudo su - oracle
Last login: Sun Oct 15 11:15:42 UTC 2023 on pts/0
[oracle@observer ~]$ dgmgrl sys/oracleA1@oradb02_dgmgrl
DGMGRL for Linux: Release 19.0.0.0.0 - Production on Sun Oct 15 13:24:18 2023
Version 19.3.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

Welcome to DGMGRL, type "help" for information.
Connected to "oradb02"
Connected as SYSDBA.
DGMGRL>
```

Prepare for failover by checking configuration.
Do a Complete manual failover (controlled way)

```powershell
DGMGRL> show configuration

Configuration - FSF

  Protection Mode: MaxAvailability
  Members:
  oradb01 - Primary database
    oradb02 - (*) Physical standby database

Fast-Start Failover: Enabled in Zero Data Loss Mode

Configuration Status:
SUCCESS   (status updated 52 seconds ago)

DGMGRL> failover to oradb02;
Performing failover NOW, please wait...
Failover succeeded, new primary is "oradb02"
DGMGRL>
```
## How to verify if the Failover occurred?

Secondary should now be Primary, and the old Primary is still not reinstated as StandBy  

```powershell
DGMGRL> show configuration;

Configuration - FSF

  Protection Mode: MaxAvailability
  Members:
  oradb02 - Primary database
    Warning: ORA-16824: multiple warnings, including fast-start failover-related warnings, detected for the database

    oradb01 - (*) Physical standby database (disabled)
      ORA-16661: the standby database needs to be reinstated

Fast-Start Failover: Enabled in Zero Data Loss Mode

Configuration Status:
WARNING   (status updated 4 seconds ago)

DGMGRL>
```
## Reinstate the old Primary, so that it can act as Standby

In the same DGMGRL session, try reinstating the Old Primary.  It would fail, because the old Primary DB is in shutdown state.

```powershell
DGMGRL> reinstate database oradb01;
Reinstating database "oradb01", please wait...
Error: ORA-16653: failed to reinstate database

Failed.
Reinstatement of database "oradb01" failed
DGMGRL>
```
### How to reinstate the old Primary

Login to the Primary node, sudo into Oracle account, and startup the primary database

```powershell
[adminusername@primary ~]$ sudo su - oracle
Last login: Sat Oct 14 16:18:51 UTC 2023
[oracle@primary ~]$ export ORACLE_SID=oradb01
[oracle@primary ~]$ sqlplus / as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Sat Oct 14 17:14:59 2023
Version 19.3.0.0.0

Copyright (c) 1982, 2019, Oracle.  All rights reserved.

Connected to an idle instance.

SQL>
SQL> startup mount;
ORACLE instance started.

Total System Global Area 8690594008 bytes
Fixed Size                  8904920 bytes
Variable Size            1409286144 bytes
Database Buffers         7247757312 bytes
Redo Buffers               24645632 bytes
Database mounted.
SQL>
```

## Display the configuration again, to verify status of Primary and Secondary

In the DGMGRL session in observer, test the configuration.  The old Primary is automatically reinstated as StandBy, due to FSFO. It may take 30-60 seconds for reinstatement.

```powershell
DGMGRL> show configuration ;

Configuration - FSF

  Protection Mode: MaxAvailability
  Members:
  oradb02 - Primary database
    oradb01 - (*) Physical standby database

Fast-Start Failover: Enabled in Zero Data Loss Mode

Configuration Status:
SUCCESS   (status updated 53 seconds ago)

DGMGRL>
```
## How was the Old Primary reinstated ?

FSFO’s action to reinstate the old Primary can be found in observer’s logs

```powershell
[oracle@observer ~]$ tail observer.log
[W000 2023-10-14T17:16:24.889+00:00] New primary is now ready to reinstate.
[W000 2023-10-14T17:16:25.889+00:00] Issuing REINSTATE command.

2023-10-14T17:16:25.889+00:00
Initiating reinstatement for database "oradb01"...
Reinstating database "oradb01", please wait...
[W000 2023-10-14T17:16:48.911+00:00] The standby oradb01 is ready to be a FSFO target
Reinstatement of database "oradb01" succeeded
2023-10-14T17:17:18.266+00:00
[W000 2023-10-14T17:17:18.936+00:00] Successfully reinstated database oradb01.
[oracle@observer ~]$
```

## Reverse roles again, to test Transparent Applciation failover

Connect to Data guard command line utility on the observer, and switch back to oradb01.

```powershell
[oracle@observer ~]$ dgmgrl sys/oracleA1@oradb01_dgmgrl
DGMGRL for Linux: Release 19.0.0.0.0 - Production on Thu Nov 2 04:34:01 2023
Version 19.3.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

Welcome to DGMGRL, type "help" for information.
Connected to "oradb01"
Connected as SYSDBA.
DGMGRL> switchover to oradb01;
Performing switchover NOW, please wait...
New primary database "oradb01" is opening...
Operation requires start up of instance "oradb02" on database "oradb02"
Starting instance "oradb02"...
Connected to an idle instance.
ORACLE instance started.
Connected to "oradb02"
Database mounted.
Database opened.
Connected to "oradb02"
Switchover succeeded, new primary is "oradb01"
DGMGRL>
```
The roles now have been reverted to initial state - oradb01 is Primary and oradb02 is secondary.

## Testing Transparent application failover(TAF)

Login to the Primary, connect SQLPlus with the TAF TNS network name

```powershell
oracle@primary ~]$ sqlplus sys/oracleA1@oradb01_taf as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Sun Oct 15 13:05:29 2023
Version 19.3.0.0.0

Copyright (c) 1982, 2019, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

SQL>
```

Verify which DB instance is the client connected to.

```powershell
SQL> select instance_name from v$instance;

INSTANCE_NAME
----------------
oradb01

SQL>
```

Run a long-running SELECT query, a sample is a cartesian join of a large table.  This will run at least for a minute.

```powershell
SQL> select a.tname, b.tname from tab a, tab b;


TNAME                                    TNAME
---------------------------------------- ----------------------------------------
TS$                                      TS$
TS$                                      ICOL$
TS$                                      C_FILE#_BLOCK#
TS$                                      USER$
TS$                                      CDEF$
TS$                                      C_TS#
TS$                                      C_COBJ#
TS$                                      CCOL$
TS$                                      SEG$
TS$                                      PROXY_DATA$
TS$                                      COL$
…
…
…
```

Simultaneously login to the Observer, sudo to Oracle account,  connect to Data guard command line to the Standby SID.

```powershell
$ ssh <adminusername>@<observerip>
Enter passphrase for key '/home/<adminusername>/.ssh/id_rsa':
Last login: Sun Oct 15 11:15:37 2023 from 49.204.116.157
[<adminusername>@observer ~]$ sudo su - oracle
Last login: Sun Oct 15 11:15:42 UTC 2023 on pts/0
[oracle@observer ~]$ dgmgrl sys/oracleA1@oradb02_dgmgrl
DGMGRL for Linux: Release 19.0.0.0.0 - Production on Sun Oct 15 13:24:18 2023
Version 19.3.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

Welcome to DGMGRL, type "help" for information.
Connected to "oradb02"
Connected as SYSDBA.
DGMGRL>
```
In the same session, initiate a Switchover to secondary DB.  While the switchover completes, the SELECT query in the other session should continue to run.

```powershell
DGMGRL> switchover to oradb02;
Performing switchover NOW, please wait...
New primary database "oradb02" is opening...
Operation requires start up of instance "oradb01" on database "oradb01"
Starting instance "oradb01"...
Connected to an idle instance.
ORACLE instance started.
Connected to "oradb01"
Database mounted.
Database opened.
Connected to "oradb01"
Switchover succeeded, new primary is "oradb02"
DGMGRL>
```

After the SELECT query has completed (Ctrl-C to break), check the instance connected to in the same session. It must be the Secondary.

Oracle Client has transparently switched a user session from Primary to secondary, while executing a query. In the case of a transaction (CRUD statements), the transaction would automatically be rolled back, and the Client will be connected to secondary

```powershell
SQL> select instance_name from v$instance;


INSTANCE_NAME
----------------
oradb02

SQL>
```

The above SQL command shows that the client is now connected to the Standby instance.

## Lab cleanup

Deleting the resource group is sufficient

```powershell
az group delete oragroup --no-wait --yes
```