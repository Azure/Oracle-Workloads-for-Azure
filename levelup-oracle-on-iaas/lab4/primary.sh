#!/bin/bash
# Script to configure primary database VM

echo '---------------------------------------------------------------------'
echo 'Create the Oracle database, configure the DB, modify TNS entries     '
echo '---------------------------------------------------------------------'
echo 
echo
echo 'Creating file systems ...' 
export datadisk=`lsscsi | grep "^\[[0-9]:[0-9]:[0-9]:1.*" | awk -F' ' '{print $NF}'`
export datadiskdevice=`echo "${datadisk}1"`
export datadiskpattern=`echo ${datadisk} | cut -d'/' -f3`
/usr/sbin/parted ${datadisk} mklabel gpt
/usr/sbin/parted -a opt ${datadisk} mkpart primary xfs 0% 100%
mkdir /u02 
/usr/sbin/mkfs.xfs ${datadiskdevice}
mount ${datadiskdevice} /u02
mkdir /u02/oradata /u02/orarecv 
chown oracle:oinstall /u02 -R
diskuuid=`ls  -l /dev/disk/by-uuid | grep ${datadiskpattern} |  awk '{i=NF-2;print $i}'`
mntopts=`sudo mount | grep u02 | awk '{print $NF}' | sed 's/(//' | sed 's/)//'`
echo UUID=$diskuuid /u02 xfs $mntopts 0 0 >> /etc/fstab
echo 'Finished creating file systems' 
echo 'disable firewall'
systemctl stop firewalld
systemctl disable firewalld

sudo su - oracle <<"SUEOF"
#!/bin/bash

#<insertVariables>

export ORACLE_SID=${_primaryOraSid}
export ORACLE_HOME=${_oraHome}
export PATH=${_oraHome}/bin:${PATH}
export TNS_ADMIN=${_oraHome}/network/admin 

echo "Create the database" 
dbca -silent -createDatabase \
-gdbName ${_primaryOraSid} \
-templateName ${_oraHome}/assistants/dbca/templates/General_Purpose.dbc \
-sid ${_primaryOraSid} \
-sysPassword ${_oraSysPwd} \
-systemPassword ${_oraSysPwd} \
-characterSet ${_oraCharSet} \
-createListener ${_oraLsnr}:${_oraLsnrPort} \
-storageType FS \
-datafileDestination ${_oraDataDir} \
-enableArchive TRUE \
-memoryMgmtType AUTO_SGA \
-memoryPercentage 70 \
-recoveryAreaDestination ${_oraFRADir} \
-recoveryAreaSize 40960 \
-redoLogFileSize ${_oraRedoSizeMB} 

_dbDataFileDir=`echo "${_primaryOraSid}" | tr [a-z] [A-Z]`
echo "Configure the database" 
sqlplus / as sysdba  << __EOF__

prompt create a DB trigger to startup a dynamic service
exec dbms_service.create_service('PRIMARY','PRIMARY');
exec dbms_service.create_service('STANDBY','STANDBY');
create or replace trigger startDgServices after startup on database
declare db_role varchar(30);
begin	
	select database_role into db_role from V\$DATABASE;
	if db_role = 'PRIMARY' then dbms_service.start_service('PRIMARY'); dbms_service.stop_service('STANDBY');
	else dbms_service.start_service('STANDBY'); dbms_service.stop_service('PRIMARY');
	end if;
END;
/
prompt set the DB into force logging
ALTER DATABASE FORCE LOGGING;
prompt set archive log destination 
ALTER SYSTEM SET LOG_ARCHIVE_DEST_1='LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=${_primaryOraSid}' SCOPE=SPFILE;
prompt set service names for Dataguard and the standard DB connection
ALTER SYSTEM SET SERVICE_NAMES='${_primaryOraSid}','${_primaryOraSid}_dgmgrl' SCOPE=BOTH;
prompt set STANDBY_FILE_MANAGEMENT to AUTO 
ALTER SYSTEM SET STANDBY_FILE_MANAGEMENT=AUTO SCOPE=BOTH;
prompt set LOG_ARCHIVE_CONFIG to standby DB SID
ALTER SYSTEM SET LOG_ARCHIVE_CONFIG='DG_CONFIG=${_stdbyOraSid}' SCOPE=BOTH;
prompt set DB_FLASHBACK_RETENTION_TARGET to 60
ALTER SYSTEM SET DB_FLASHBACK_RETENTION_TARGET=60 SCOPE=BOTH;
prompt configure Dataguard broker config files
ALTER SYSTEM SET DG_BROKER_CONFIG_FILE1='${_oraDataDir}/dgbcf01.dat' SCOPE=BOTH;
ALTER SYSTEM SET DG_BROKER_CONFIG_FILE2='${_oraFRADir}/dgbcf02.dat' SCOPE=BOTH;
prompt set dataguard broker init 
ALTER SYSTEM SET DG_BROKER_START=TRUE SCOPE=BOTH;
prompt create four standby logfile groups
ALTER DATABASE ADD STANDBY LOGFILE GROUP 11 '${_oraFRADir}/${_dbDataFileDir}/stby-t01-g11-m1.log' SIZE ${_oraRedoSizeMB}M;
ALTER DATABASE ADD STANDBY LOGFILE GROUP 12 '${_oraFRADir}/${_dbDataFileDir}/stby-t01-g12-m1.log' SIZE ${_oraRedoSizeMB}M;
ALTER DATABASE ADD STANDBY LOGFILE GROUP 13 '${_oraFRADir}/${_dbDataFileDir}/stby-t01-g13-m1.log' SIZE ${_oraRedoSizeMB}M;
ALTER DATABASE ADD STANDBY LOGFILE GROUP 14 '${_oraFRADir}/${_dbDataFileDir}/stby-t01-g14-m1.log' SIZE ${_oraRedoSizeMB}M;
prompt shutdown and restart
SHUTDOWN IMMEDIATE
STARTUP MOUNT
prompt set protection mode to MAXIMIZE AVAILABILITY
ALTER DATABASE SET STANDBY DATABASE TO MAXIMIZE AVAILABILITY;
prompt set DB into flashback mode
ALTER DATABASE FLASHBACK ON;

exit success;
__EOF__

echo Modify tnsnames.ora 
cat >> ${TNS_ADMIN}/tnsnames.ora << TNSHERE
# Custom TNS name entries

${_primaryOraSid}=
  (DESCRIPTION = (FAILOVER = ON)(LOAD_BALANCE = OFF)
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${_vmName1}.${_vmDomain})(PORT = 1521))
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${_vmName2}.${_vmDomain})(PORT = 1521))
    )
    (CONNECT_DATA = 
        (SERVICE_NAME = PRIMARY)
        (SERVER = DEDICATED)
    )
  ) 

${_primaryOraSid}_${_vmNbr1}=
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${_vmName1}.${_vmDomain})(PORT = 1521))
    )
    (CONNECT_DATA =  
        (SERVICE_NAME = ${_primaryOraSid}_${_vmNbr1})
        (SERVER = DEDICATED)
    )
  )

${_stdbyOraSid}_${_vmNbr2}=
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${_vmName2}.${_vmDomain})(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVICE_NAME = ${_stdbyOraSid}_${_vmNbr2})
      (SERVER = DEDICATED)
    )
  )

${_primaryOraSid}_dgmgrl =
  (DESCRIPTION =
    (ADDRESS_LIST = 
    	(ADDRESS = (PROTOCOL = TCP)(HOST = ${_vmName1}.${_vmDomain})(PORT = 1521))
    )
    (CONNECT_DATA =
            (SERVER = DEDICATED)
            (SERVICE_NAME = ${_primaryOraSid}_dgmgrl)
	  )
  )

${_stdbyOraSid}_dgmgrl =
  (DESCRIPTION =
    (ADDRESS_LIST = 
    	(ADDRESS = (PROTOCOL = TCP)(HOST = ${_vmName2}.${_vmDomain})(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ${_stdbyOraSid}_dgmgrl)
	  )
  )

${_primaryOraSid}_taf =
  (DESCRIPTION = 
    (FAILOVER = ON)
    (LOAD_BALANCE = OFF)
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${_vmName1}.${_vmDomain})(PORT = 1521))
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${_vmName2}.${_vmDomain})(PORT = 1521))
    )
    (CONNECT_DATA = 
      (SERVICE_NAME = PRIMARY)
      (FAILOVER_MODE =
        (TYPE = SELECT)
        (METHOD = BASIC)
        (RETRIES = 300)
        (DELAY = 1)
      )
    )
  )

TNSHERE

echo "Reloading the Listener" 
cat >> ${_oraHome}/network/admin/listener.ora << LSNREOF
SID_LIST_${_oraLsnr}=
(SID_LIST =
  (SID_DESC = 
    (GLOBAL_DBNAME = ${_primaryOraSid}_dgmgrl)
    (ORACLE_HOME = ${_oraHome})
    (SID_NAME = ${_primaryOraSid})
  )
)
LSNREOF
lsnrctl reload ${_oraLsnr} 

echo startup force 
export ORACLE_SID=${_primaryOraSid}
echo Oracle SiD is ${ORACLE_SID}
sqlplus / as sysdba << __SFEOF__
prompt starting the database
STARTUP FORCE
prompt open database for readwrite
alter database open;
prompt verify force logging status
select name, force_logging from v\$database;
prompt verify archive log destination
archive log list
prompt verify standby file management
show parameter STANDBY_FILE_MANAGEMENT
prompt verify LOG_ARCHIVE_CONFIG
show parameter LOG_ARCHIVE_CONFIG
prompt verify flashback retention target
show parameter DB_FLASHBACK_RETENTION_TARGET
prompt verify database is open
select name,open_mode from v\$database;
prompt verify DG broker config files
show parameter DG_BROKER_CONFIG_FILE1
show parameter DG_BROKER_CONFIG_FILE2
prompt verify DG broker started status
show parameter DG_BROKER_START
prompt verify protection mode
select name,protection_mode from v\$database;
prompt verify the DB role, failover mode, and flashback
select name, database_role,fs_failover_mode,flashback_on from v\$database;
exit success
__SFEOF__

SUEOF

echo '---------------------------------------------------------------------'
echo 'All complete.    '
echo '---------------------------------------------------------------------'
