#!/bin/bash
#================================================================================
# Name: azbackup_verify.sh
# Type: bash script
# Date: 30-June 2021
# From: Customer Architecture & Engineering (CAE) - Microsoft
#
# Copyright and license:
#
#       Licensed under the Apache License, Version 2.0 (the "License"); you may
#       not use this file except in compliance with the License.
#
#       You may obtain a copy of the License at
#
#               http://www.apache.org/licenses/LICENSE-2.0
#
#       Unless required by applicable law or agreed to in writing, software
#       distributed under the License is distributed on an "AS IS" basis,
#       WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#
#       See the License for the specific language governing permissions and
#       limitations under the License.
#
#       Copyright (c) 2021 by Microsoft.  All rights reserved.
#
# Ownership and responsibility:
#
#       This script is offered without warranty by Microsoft Customer Engineering.
#       Anyone using this script accepts full responsibility for use, effect,
#       and maintenance.  Please do not contact Microsoft support unless there
#       is a problem with a supported Azure component used in this script,
#       such as an "az" command.
#
# Description:
#
#       Script to automate diagnosis of the Linux client-side configuration of
#       Azure VM Backup for integration with one or more Oracle databases on a VM.
#
# Command-line Parameters:
#       Any command-line parameter will place the script into "verbose" mode.  Silent
#       mode is the default if no command-line parameters are specified.
#
# Prerequisites:
#
#       Full "sudo" permissions are *required* in the Linux OS account which runs
#       this script.
#
#       This script should be run under the administrative Linux OS account
#       for this Azure VM (which is granted full "sudo" permissions at VM creation),
#       or else under the Linux root OS account.
#
# Validations performed:
#
#       1. existence and contents of the "/etc/azure/workload.conf" config file
#               a. validate "workload_type" specified in config file is "oracle"
#               b. validate "configuration_path" specified is a file with entries
#                  in correct format
#               c. validate "timeout" specified in config file between 0 and 3600 seconds
#               d. validate Linux OS account specified as "linux_user" in config file
#               e. validate Linux OS group assigned to "linux_user" is Oracle
#                  SYSBACKUP group
#       2. existence of Oracle "pre-script" and "post-script"
#               a. within root-protected "/var/lib/waagent" subdirectory
#       3. For each Oracle database instance listed in the file referenced by
#          "configuration_path"...
#               a. validate existence of "$ORACLE_HOME" directory and specific
#                  subdirectories
#               b. validate existence of "config.c" source file
#               c. validate that the defined Linux OS group for OS authentication
#                  of the SYSBACKUP role is the primary OS group of the Linux OS
#                  account (i.e. "linux_user" attribute)
#               d. validate that it is possible to connect to Oracle SQL*Plus
#                  under the Linux OS account for Azure VM Backup with the
#                  SYSBACKUP role
#               e. validate that the AZMESSAGE stored procedure exists and is VALID
#
# Modifications:
#       TGorman 30jun21 v1.0    initially written
#       TGorman 30jun21 v1.1    silent mode (no output) default; add verbose mode
#       TGorman 30jul21 v1.2    verbose mode made the default; terse by parm only
#       TGorman 18aug21 v1.3    clarify errmsg when Oracle instance down
#       TGorman 21dec21 v1.4    skip past ASM instances in configuration file
#       TGorman 11feb22 v1.5    added more detail to INFO messages for clarity
#       TGorman 16feb22 v1.6    fixed looping bug
#================================================================================
_scriptVersion="1.6"
_lastUpdated="16-Feb 2022"
#
#--------------------------------------------------------------------------------
# Create shell function to display messages in "verbose" mode;  "silent" mode is
# the default mode...
#--------------------------------------------------------------------------------
_verbose_msg()
{
        if [[ "${_verboseMode}" = "true" ]]
        then
                echo "`date` - INFO: $1"
        fi
}
_verboseMode="true"
if (( $# == 1 ))
then
        _verboseMode="false"
fi
_verbose_msg "verbose mode enabled, script version ${_scriptVersion}, last updated ${_lastUpdated}"
#
#--------------------------------------------------------------------------------
# Set program variables...
#--------------------------------------------------------------------------------
typeset -i _errCnt=0
_confDir=/etc/azure
_confFile=${_confDir}/workload.conf
#
#--------------------------------------------------------------------------------
# Verify that the directory in which the Azure VM Backup configuration file
# resides exists...
#--------------------------------------------------------------------------------
_verbose_msg "Configuration file: verify existence of directory \"${_confDir}\""
if [ ! -d ${_confDir} ]
then
        echo "`date` - FAIL: directory \"${_confDir}\" not found"
        typeset -i _errCnt=${_errCnt}+1
fi
_verbose_msg "Configuration file: ...verified"
#
#--------------------------------------------------------------------------------
# Verify that the Azure VM Backup configuration file exists...
#--------------------------------------------------------------------------------
_verbose_msg "Configuration file: verify existence of file \"${_confFile}\""
if [ ! -f ${_confFile} ]
then
        echo "`date` - FAIL: Azure VM Backup configuration file \"${_confFile}\" not found"
        typeset -i _errCnt=${_errCnt}+1
fi
_verbose_msg "Configuration file: ...verified"
#
#--------------------------------------------------------------------------------
# Verify the first line of the Azure VM Backup configuration file...
#--------------------------------------------------------------------------------
_verbose_msg "Configuration file: verify header of file \"${_confFile}\"..."
_confFileHdr=`head -1 ${_confFile} | awk '{print $1}'`
if [[ "${_confFileHdr}" != "[workload]" ]]
then
        echo "`date` - FAIL: Azure VM Backup configuration file \"${_confFile}\" misconfigured - missing \"[workload]\""
        typeset -i _errCnt=${_errCnt}+1
fi
_verbose_msg "Configuration file: ...header is \"[workload]\""
#
#--------------------------------------------------------------------------------
# Verify the specification of the "workload_name" attribute in the Azure VM
# Backup configuration file...
#--------------------------------------------------------------------------------
_verbose_msg "Configuration file: verify \"workload_name\" attribute in file \"${_confFile}\"..."
_workloadNameSpec=`grep -E "^workload_name\s+=\s+oracle$" ${_confFile}`
if [[ "${_workloadNameSpec}" = "" ]]
then
        echo "`date` - FAIL: Azure VM Backup configuration file \"${_confFile}\" misconfigured - missing \"workload_name = oracle\""
        typeset -i _errCnt=${_errCnt}+1
fi
_workloadName=`echo ${_workloadNameSpec} | awk '{print $3}'`
if [[ "${_workloadName}" != "oracle" ]]
then
        echo "`date` - FAIL: Azure VM Backup configuration file \"${_confFile}\", workload_name is \"${_workloadName}\", should be \"oracle\""
        typeset -i _errCnt=${_errCnt}+1
fi
_verbose_msg "Configuration file: ...attribute \"workload_name\" is \"${_workloadName}\""
#
#--------------------------------------------------------------------------------
# Verify the specification of the "configuration_path" attribute in the Azure VM
# Backup configuration file...
#--------------------------------------------------------------------------------
_verbose_msg "Configuration file: verify \"configuration_path\" attribute in file \"${_confFile}\"..."
_confPathSpec=`grep -E "^configuration_path\s+=\s+" ${_confFile}`
if [[ "${_confPathSpec}" = "" ]]
then
        echo "`date` - FAIL: Azure VM Backup configuration file \"${_confFile}\" misconfigured - missing \"configuration_path\""
        typeset -i _errCnt=${_errCnt}+1
fi
_confPath=`echo ${_confPathSpec} | awk -F= '{print $2}' | sed 's/ //g'`
if [[ "${_confPath}" = "" ]]
then
        echo "`date` - FAIL: Azure VM Backup configuration file \"${_confFile}\" misconfigured - missing value for \"configuration_path\""
        typeset -i _errCnt=${_errCnt}+1
fi
if [ ! -r ${_confPath} ]
then
        echo "`date` - FAIL: Azure VM Backup configuration file \"${_confFile}\" misconfigured - file \"${_confPath}\" not found"
        typeset -i _errCnt=${_errCnt}+1
fi
_verbose_msg "Configuration file: ...attribute \"configuration_path\" is \"${_confPath}\""
#
#--------------------------------------------------------------------------------
# Verify the specification of the "timeout" attribute in the Azure VM Backup
# configuration file...
#--------------------------------------------------------------------------------
_verbose_msg "Configuration file: verify \"timeout\" attribute in file \"${_confFile}\"..."
_timeoutSpec=`grep -E "^timeout\s+=\s+[0-9][0-9][0-9]*$" ${_confFile}`
if [[ "${_timeoutSpec}" = "" ]]
then
        echo "`date` - FAIL: Azure VM Backup configuration file \"${_confFile}\" misconfigured - missing \"timeout\""
        typeset -i _errCnt=${_errCnt}+1
fi
_timeout=`echo ${_timeoutSpec} | awk -F= '{print $2}' | sed 's/ //g'`
if [[ "${_timeout}" = "" ]]
then
        echo "`date` - FAIL: Azure VM Backup configuration file \"${_confFile}\" misconfigured - missing value for \"timeout\""
        typeset -i _errCnt=${_errCnt}+1
fi
if (( ${_timeout} < 0 || ${_timeout} > 3600 ))
then
        echo "`date` - FAIL: Azure VM Backup configuration file \"${_confFile}\" misconfigured - value for \"timeout\" not between 0 and 3600"
        typeset -i _errCnt=${_errCnt}+1
fi
_verbose_msg "Configuration file: ...attribute \"timeout\" is ${_timeout} seconds"
#
#--------------------------------------------------------------------------------
# Verify the specification of the "linux_user" attribute in the Azure VM Backup
# configuration file.  Also, verify that the Linux OS account exists, and that
# the OS group primary for the user account is recorded for later verification...
#--------------------------------------------------------------------------------
_verbose_msg "Configuration file: verify \"linux_user\" attribute in file \"${_confFile}\"..."
_linuxUserSpec=`grep -E "^linux_user\s+=\s+" ${_confFile}`
if [[ "${_linuxUserSpec}" = "" ]]
then
        echo "`date` - FAIL: Azure VM Backup configuration file \"${_confFile}\" misconfigured - missing \"linux_user\""
        typeset -i _errCnt=${_errCnt}+1
fi
_linuxUser=`echo ${_linuxUserSpec} | awk -F= '{print $2}' | awk '{print $1}'`
if [[ "${_timeout}" = "" ]]
then
        echo "`date` - FAIL: Azure VM Backup configuration file \"${_confFile}\" misconfigured - missing value for \"linux_user\""
        typeset -i _errCnt=${_errCnt}+1
fi
#
_effUserId=`id -u ${_linuxUser}`
if (( $? != 0 ))
then
        echo "`date` - FAIL: Azure VM Backup configuration file \"${_confFile}\" misconfigured - invalid value \"${_linuxUser}\" for \"linux_user\""
        exit 1
fi
_effGrpId=`id -g ${_linuxUser}`
if (( $? != 0 ))
then
        echo "`date` - FAIL: \"id -g ${_linuxUser}\" failed; aborting..."
        exit 1
fi
_grpSpec=`grep ":${_effGrpId}:" /etc/group`
if (( $? != 0 ))
then
        echo "`date` - FAIL: \"grep :${_effGrpId}: /etc/group\" failed; aborting..."
        exit 1
fi
_osGrpName=`echo ${_grpSpec} | awk -F: '{print $1}'`
_verbose_msg "Configuration file: ...attribute \"linux_user\" is \"${_linuxUser}\" (belonging to OS group \"${_osGrpName}\")"
#
#--------------------------------------------------------------------------------
# Verify that the Oracle master pre-script and post-script files exist within the
# "/var/lib/waagent" directory, which is accessible only by "root".  If possible,
# use "sudo" to verify the presence of the files...
#--------------------------------------------------------------------------------
_verbose_msg "Azure Linux agent: verify existence of pre-script..."
_preScriptFile=`sudo -n find /var/lib/waagent -name preOracleMaster.sql 2> /dev/null`
if (( $? != 0 ))
then
        echo "`date` - FAIL: \"sudo -n find /var/lib/waagent -name preOracleMaster.sql\" failed, probably due to lack of \"sudo\" permissions"
        typeset -i _errCnt=${_errCnt}+1
else
        if [[ "${_preScriptFile}" = "" ]]
        then
                echo "`date` - FAIL: unable to locate pre-script within \"/var/lib/waagent/Microsoft.Azure.RecoveryServices.VMSnapshotLinux-\*/main/workloadPatch/DefaultScripts\" directory"
                typeset -i _errCnt=${_errCnt}+1
        fi
        _verbose_msg "Azure Linux agent: ...pre-script is \"${_preScriptFile}\""
fi
_verbose_msg "Azure Linux agent: verify existence of post-script..."
_postScriptFile=`sudo -n find /var/lib/waagent -name postOracleMaster.sql 2> /dev/null`
if (( $? != 0 ))
then
        echo "`date` - FAIL: \"sudo -n find /var/lib/waagent -name postOracleMaster.sql\" failed, probably due to lack of \"sudo\" permissions"
        typeset -i _errCnt=${_errCnt}+1
else
        if [[ "${_postScriptFile}" = "" ]]
        then
                echo "`date` - FAIL: unable to locate post-script within \"/var/lib/waagent/Microsoft.Azure.RecoveryServices.VMSnapshotLinux-\*/main/workloadPatch/DefaultScripts\" directory"
                typeset -i _errCnt=${_errCnt}+1
        fi
        _verbose_msg "Azure Linux agent: ...post-script is \"${_postScriptFile}\""
fi
#
#------------------------------------------------------------------------
# Create a temporary SQL*Plus script to be used to verify whether the
# database account for Azure VM Backup is created properly...
#------------------------------------------------------------------------
_tmpSqlScriptFile=/tmp/azbackup_verify_$$.sql
_tmpSqlOutFile=/tmp/azbackup_verify_$$.out
rm -f ${_tmpSqlScriptFile}
echo "whenever oserror exit 1"                          >> ${_tmpSqlScriptFile}
echo "set echo on feedback on timing on heading off"    >> ${_tmpSqlScriptFile}
echo "set pages 100 lines 130 trimout on trimspool on"  >> ${_tmpSqlScriptFile}
echo "whenever sqlerror exit 2"                         >> ${_tmpSqlScriptFile}
echo "connect / as sysbackup"                           >> ${_tmpSqlScriptFile}
echo "whenever sqlerror exit 3"                         >> ${_tmpSqlScriptFile}
echo "select 'azmessage='||status from all_objects"     >> ${_tmpSqlScriptFile}
echo "where owner = 'SYSBACKUP'"                        >> ${_tmpSqlScriptFile}
echo "and object_name = 'AZMESSAGE'"                    >> ${_tmpSqlScriptFile}
echo "and object_type = 'PROCEDURE';"                   >> ${_tmpSqlScriptFile}
echo "exit success"                                     >> ${_tmpSqlScriptFile}
#
#--------------------------------------------------------------------------------
# Read through each of the non-comment non-blank lines in the Oracle database
# configuration file.  Each line should have two fields separated by colon chars,
# the first field containing ORACLE_SID value and the second field containing the
# ORACLE_HOME directory path...
#--------------------------------------------------------------------------------
grep -v -e '^#' -e '^+' -e '^$' ${_confPath} | while read _Line
do
        #
        #------------------------------------------------------------------------
        # Extract the ORACLE_SID and ORACLE_HOME values from the line text...
        #------------------------------------------------------------------------
        _oraSid=`echo ${_Line} | awk -F: '{print $1}'`
        _oraHome=`echo ${_Line} | awk -F: '{print $2}'`
        #
        #------------------------------------------------------------------------
        # Verify the ORACLE_HOME directory and the "rdbms/lib" subdirectories in
        # which the source file "config.c" resides...
        #------------------------------------------------------------------------
        _verbose_msg "DB instance \"${_oraSid}\": validate ORACLE_HOME directory \"${_oraHome}\""
        if [ ! -d ${_oraHome} ]
        then
                echo "`date` - FAIL: Oracle configuration file \"${_confPath}\" - directory \"${_oraHome}\" not found"
                typeset -i _errCnt=${_errCnt}+1
        fi
        if [ ! -d ${_oraHome}/rdbms/lib ]
        then
                echo "`date` - FAIL: Oracle configuration file \"${_confPath}\" - directory \"${_oraHome}/rdbms/lib\" not found"
                typeset -i _errCnt=${_errCnt}+1
        fi
        if [ ! -r ${_oraHome}/rdbms/lib/config.c ]
        then
                echo "`date` - FAIL: Oracle configuration file \"${_confPath}\" - file \"${_oraHome}/rdbms/lib/config.c\" not found"
                typeset -i _errCnt=${_errCnt}+1
        fi
        #
        #------------------------------------------------------------------------
        # Extract the name of the Linux OS group which represents the SYSBACKUP
        # database role for OS authentication.  Verify that the OS group to
        # which the configure "linux_user" belongs matches the Linux OS group
        # representing the Oracle SYSBACKUP database role...
        #------------------------------------------------------------------------
        _verbose_msg "DB instance \"${_oraSid}\": validate SYSBACKUP group in \"${_oraHome}/rdbms/lib/config.c\""
        _sysbackupSpec=`grep "^#define SS_BKP_GRP " ${_oraHome}/rdbms/lib/config.c`
        if [[ "${_sysbackupSpec}" = "" ]]
        then
                echo "`date` - FAIL: Oracle source file \"${_oraHome}/rdbms/lib/config.c\" - \"SS_BKP_GRP\" entry not found"
                typeset -i _errCnt=${_errCnt}+1
        fi
        _sysbackupGrp=`echo ${_sysbackupSpec} | awk '{print $3}' | sed 's/"//g'`
        if [[ "${_sysbackupGrp}" != "${_osGrpName}" ]]
        then
                echo "`date` - FAIL: Oracle SYSBACKUP group is \"${_sysbackupGrp}\", \"${_linuxUser}\" group is \"${_osGrpName}\""
                typeset -i _errCnt=${_errCnt}+1
        fi
        #
        #------------------------------------------------------------------------
        # Run the temporary SQL*Plus script while connected as SYSBACKUP to
        # validate the database setup for Azure VM Backup...
        #------------------------------------------------------------------------
        _verbose_msg "DB instance \"${_oraSid}\": connect through \"${_linuxUser}\" OS account externally as \"/ AS SYSBACKUP\""
        sudo -n su - ${_linuxUser} -c "if [[ \"`ps -eaf | grep pmon | grep -v grep`\" = \"\" ]]; then exit 9; fi; export ORACLE_SID=${_oraSid}; export ORACLE_HOME=${_oraHome}; export PATH=${oraHome}/bin:\${PATH}; ${_oraHome}/bin/sqlplus -S -R 2 /nolog @${_tmpSqlScriptFile} > ${_tmpSqlOutFile} 2>&1"
        case $? in
                0)      ;;
                1)      echo "`date` - FAIL: Oracle SQL*Plus SET command failed in \"${_oraSid}\" database instance"
                        typeset -i _errCnt=${_errCnt}+1
                        ;;
                2)      echo "`date` - FAIL: CONNECT / AS SYSBACKUP failed in \"${_oraSid}\" database instance"
                        typeset -i _errCnt=${_errCnt}+1
                        ;;
                3)      echo "`date` - FAIL: AZMESSAGE not found in \"${_oraSid}\" database instance"
                        typeset -i _errCnt=${_errCnt}+1
                        ;;
                9)      echo "`date` - FAIL: database instance \"${_oraSid}\" not running"
                        typeset -i _errCnt=${_errCnt}+1
                        ;;
                *)      echo "`date` - FAIL: unknown SQL*Plus error in \"${_oraSid}\" database instance"
                        typeset -i _errCnt=${_errCnt}+1
                        ;;
        esac
        #
        #------------------------------------------------------------------------
        # Check whether the appropriate message was generated indicating that the
        # AZMESSAGE stored procedure is valid or not...
        #------------------------------------------------------------------------
        grep 'azmessage=' ${_tmpSqlOutFile} > /dev/null 2>&1
        if (( $? == 0 ))
        then
                grep 'azmessage=VALID' ${_tmpSqlOutFile} > /dev/null 2>&1
                if (( $? != 0 ))
                then
                        echo "`date` - FAIL: AZMESSAGE not VALID in \"${_oraSid}\" database instance"
                        typeset -i _errCnt=${_errCnt}+1
                fi
        fi
        #
done
#
#--------------------------------------------------------------------------------
# Clean up temporary files...
#--------------------------------------------------------------------------------
sudo -n rm -f ${_tmpSqlOutFile} ${_tmpSqlScriptFile}
#
#--------------------------------------------------------------------------------
# Successful script completion...
#--------------------------------------------------------------------------------
if (( ${_errCnt} > 0 ))
then
        echo "`date` - FAIL: check and resolve all error messages"
        exit 1
else
        _verbose_msg "validated successfully"
        exit 0
fi
