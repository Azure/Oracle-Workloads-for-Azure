#!/bin/bash
# Script to configure observer database VM
echo '---------------------------------------------------------------------'
echo 'Configure Data guard replication settings, start the observer        '
echo '---------------------------------------------------------------------'
echo 
echo
sudo -E su - oracle <<"SUEOF"
#!/bin/bash

#<insertVariables>

export ORACLE_SID=${_primaryOraSid}
export ORACLE_HOME=${_oraHome}
export PATH=${_oraHome}/bin:${PATH}
export TNS_ADMIN=${_oraHome}/network/admin 


echo Modify tnsnames.ora 
cat >> ${TNS_ADMIN}/tnsnames.ora << TNSHERE

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

echo Starting Data guard configuration
export ORACLE_SID=${_primaryOraSid}
dgmgrl sys/${_oraSysPwd}@${_primaryOraSid}_dgmgrl << __EOF__

create configuration 'FSF' as primary database is ${_primaryOraSid} connect identifier is ${_primaryOraSid}_dgmgrl;
add database ${_stdbyOraSid} as connect identifier is ${_stdbyOraSid}_dgmgrl maintained as physical;

edit database ${_primaryOraSid} set property LogXptMode='SYNC';
edit database ${_primaryOraSid} set property NetTimeout=10;
edit database ${_stdbyOraSid} set property LogXptMode='SYNC';
edit database ${_stdbyOraSid} set property NetTimeout=10;

enable configuration;
host sleep 10
show configuration
enable fast_start failover;    
host sleep 10

__EOF__

echo Create a script to launch the observer
cat >> /home/oracle/observer_start.sh << _CAT_
  #!/bin/bash
  # This script is used to start the Observer in the background.

  export ORACLE_SID=${_primaryOraSid}
  dgmgrl << STEOF
    connect sys/${_oraSysPwd}@${_primaryOraSid}_dgmgrl 
    show configuration
    show fast_start failover
    start observer
STEOF

_CAT_

echo Run the observer script in background
chmod +x /home/oracle/observer_start.sh
nohup /home/oracle/observer_start.sh > /home/oracle/observer.log 2>/home/oracle/observer.err &

echo "Observer has been started."

SUEOF

echo '---------------------------------------------------------------------'
echo 'All complete.    '
echo '---------------------------------------------------------------------'
