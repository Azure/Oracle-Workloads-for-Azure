# azbackup
Useful scripts for diagnosing issues with Azure VM Backup for app-consistent Oracle database backups

# bash script "azbackup_verify.sh"

This script is intended for use in validating and troubleshooting the configuration of an Azure Linux VM for app-consistent backups of Oracle databases using Azure VM Backup.

### Prerequisites

Full "sudo" permissions are *required* by this script.

This script uses the "sudo" privilege escalation command, and so it should be run under the administrative Linux OS account for this Azure VM (which is granted full "sudo" permissions at VM creation), or else run under the Linux root OS account.

### Validations performed

    1. existence and contents of the "/etc/azure/workload.conf" config file
       a. validate "workload_type" specified in config file is "oracle"
       b. validate "configuration_path" specified is a file with entries in correct format
       c. validate "timeout" specified in config file between 0 and 3600 seconds
       d. validate Linux OS account specified as "linux_user" in config file
       e. validate Linux OS group assigned to "linux_user" is Oracle SYSBACKUP group
    2. existence of Oracle "pre-script" and "post-script"
       a. within root-protected "/var/lib/waagent" subdirectory
    3. For each Oracle database instance listed in the file referenced by "configuration_path"...
       a. validate existence of "$ORACLE_HOME" directory and specific subdirectories
       b. validate existence of "config.c" source file
       c. validate that the defined Linux OS group for OS authentication of the SYSBACKUP role is the primary OS group of the Linux OS account (i.e. "linux_user" attribute)
       d. validate that it is possible to connect to Oracle SQL*Plus under the Linux OS account for Azure VM Backup with the SYSBACKUP role
       e. validate that the AZMESSAGE stored procedure exists and is VALID

Please note that the validations within the database (i.e. existence and validity of AZMESSAGE procedure, etc) are performed using the OS account specified in the "linux_user" attribute of the configuration file, using Oracle external OS authentication through the SYSBACKUP role.

In other words, successful validation with this script includes database connections using the same authentication methods used by Azure VM Backup through the Azure Linux agent (waagent).

### Command-line Parameters
Any command-line parameter will place the script into "verbose" mode.  Silent mode is the default if no command-line parameters are specified.
       
### Return status
    0 - success
    1 - failure, please refer to error messages emitted by the script

## Examples

An example of running the script in the default "verbose" mode, no command-line parameters, and then checking the return status...


    [adminuser@ora-bkp-vm01 tmp]$ ./azbackup_verify.sh
    Sat Jul 31 18:06:27 UTC 2021 - INFO: verbose mode enabled, script version 1.2
    Sat Jul 31 18:06:27 UTC 2021 - INFO: Configuration file: verify existence of directory "/etc/azure"
    Sat Jul 31 18:06:27 UTC 2021 - INFO: Configuration file: verify existence of file "/etc/azure/workload.conf"
    Sat Jul 31 18:06:27 UTC 2021 - INFO: Configuration file: verify header of file "/etc/azure/workload.conf"
    Sat Jul 31 18:06:27 UTC 2021 - INFO: Configuration file: verify "workload_name" attribute in file "/etc/azure/workload.conf"
    Sat Jul 31 18:06:27 UTC 2021 - INFO: Configuration file: verify "configuration_path" attribute in file "/etc/azure/workload.conf"
    Sat Jul 31 18:06:27 UTC 2021 - INFO: Configuration file: verify "timeout" attribute in file "/etc/azure/workload.conf"
    Sat Jul 31 18:06:27 UTC 2021 - INFO: Configuration file: verify "linux_user" attribute in file "/etc/azure/workload.conf"
    Sat Jul 31 18:06:27 UTC 2021 - INFO: Azure Linux agent: verify existence of pre-script within directory "/var/lib/waagent"
    Sat Jul 31 18:06:27 UTC 2021 - INFO: Azure Linux agent: verify existence of post-script within directory "/var/lib/waagent"
    Sat Jul 31 18:06:27 UTC 2021 - INFO: DB instance "oradb01": validate ORACLE_HOME directory "/u01/app/oracle/product/19.0.0/dbhome_1"
    Sat Jul 31 18:06:27 UTC 2021 - INFO: DB instance "oradb01": verify SYSBACKUP group in "/u01/app/oracle/product/19.0.0/dbhome_1/rdbms/lib/config.c"
    Sat Jul 31 18:06:27 UTC 2021 - INFO: DB instance "oradb01": connect externally through "azbackup" OS account as "SYSBACKUP"
    Sat Jul 31 18:06:29 UTC 2021 - INFO: validated successfully
    [adminuser@ora-bkp-vm01 ]$ echo $?
    0
    [adminuser@ora-bkp-vm01 ]$ 


Now, running the script in the silent "terse" mode and again checking the return status...


    [adminuser@ora-bkp-vm01 ]$ ./azbackup_verify.sh terse
    [adminuser@ora-bkp-vm01 ]$ echo $?
    0
    [adminuser@ora-bkp-vm01 ]$ 


Any detected failure conditions will include the word "FAIL" in place of the word "INFO" after the timestamp.
