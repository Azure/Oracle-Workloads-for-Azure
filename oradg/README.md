## Azure CLI script to configure Oracle DataGuard FSFO

This bash script (i.e. "cr_oradg.sh") includes Azure CLI commands to fully automate the following steps of configuring Oracle DataGuard Fast-Start Failover (FSFO), consisting of two "database" hosts and one "observer" host, given a subscription and a resource group...

1. Create a storage account in the specified Azure region
2. Create a virtual network (vnet) and subnet
3. Create a network security group (NSG) and rules to permit access by SSH
4. Create two "database" VMs and one "observer" VM, using an Oracle database Enterprise Edition URN from the marketplace
5. Create a data disk on each "database" VM using the specified managed disk
6. Label, paritition, and format the data disk into an XFS filesystem mounted at "/u02" on each "database" VM
7. Use the Oracle Database Creation Assistant (DBCA) to create an Oracle database and listener on the primary "database" VM
8. Configure the primary database for DataGuard
9. Duplicate the primary database to the standby "database" VM using DBCA
10. Configuration the standby database for DataGuard
11. Finish the DataGuard FSFO configuration using the DataGuard DGMGRL utility
12. Configure the "observer" VM and start the "observer" process

Each of the three VMs have public IP addresses with SSH public-key authentication (PKA) established, so the public IP addresses can be viewed either through the Azure Portal or in the output from the "cr_oradg.sh" script.

## Sample output from Azure CLI script

Sample output can be found in the file "cr_oradg_output.txt".

## Examples of script usage

First of all, the "cr_oradg.sh" script expects to do all of its work within an Azure subscription and an Azure resource group.

The name of the Azure subscription has no default value, so the "-S" command-line switch followed by the name of the Azure subscription (possibly enclosed within double-quotes if the subscription name includes spaces) is always required...

    $ ./cr_oradg.sh -S MySubscriptionName

The name of the Azure resource group defaults to "{owner}-{project}-rg", where "{owner}" is the name of the OS account in which the script is being executed (i.e. output from "whoami" command) and "{project}" defaults to the string "oradg".  The "{owner}-{project}" string combination is used a lot within the script for naming objects like resource groups, VMs, storage, PPGs, etc.  So with this minimal call syntax, where only the name of the Azure subscription is specified, will result in the script expecting a resource group to already exist with the name of "{owner}-oradg-rg", where "{owner}" is the OS account name of the Azure CLI shell running the script.  For example, when the author uses "https://shell.azure.com", the resulting OS account name is "tim", so using this minimal call syntax for the "cr_oradg.sh" script means that it expects an Azure resource group named "tim-oradg-rg" to exist already, and it will create about 14 Azure objects with a prefix of "tim-oradg-".  If you don't want the resource group to be required to have this name, then both these basic values can be changed from the defaults using the "-O" and "-P" command-line switches, respectively...

    $ ./cr_oradg.sh -S MySubscriptionName -O test -P foobar

As a result, the name of the resource group will be expected to be "test-foobar-rg", and all of the Azure objects created within the resource group will also be named with the prefix string of "test-foobar-".  If the name of the resource group is something else (i.e. "MyResourceGroupName") but you'd like all of the objects created by the script to start with the prefix string "test-foobar-", then you can use the following call syntax...

    $ ./cr_oradg.sh -S MySubscriptionName -R MyResourceGroupName -O test -P foobar

As a result, the precreated resource group named "MyResourceGroupName" within the existing "MySubscriptionName" subscription will be populated with objects with names like "test-foobar-vm01", "test-foobar-vnet", "test-foobar-vnet", etc.

Please see the next section for a complete list of all of the command-line switches, what they control, and default values...

## Script command-line syntax

The script has command-line parameters, all of which have default values.  To display the usage message, enter "`./cr_oradg.sh -h`"...

	cr_oradg.sh -G val -H val -I val -N -M -O val -P val -S val -c val -d val -i val -p val -r val -s val -u val -v -w val

	where:

	-G resource-group-name	name of the Azure resource group (default: `{_azureOwner}-{_azureProject}-rg`)
	-H ORACLE_HOME		full path of the ORACLE_HOME software (default: /u01/app/oracle/product/12.2.0/dbhome_1)
	-I obsvr-instance-type	name of the Azure VM instance type for DataGuard observer node (default: Standard_D2_v4)
	-N			skip steps to create vnet/subnet, public-IP, NSG, rules, and PPG (default: false)
	-M			skip steps to create VMs and storage (default: false)
	-O owner-tag		name of the owner to use in Azure tags (default: `whoami`)
	-P project-tag		name of the project to use in Azure tags (default: oradg)
	-S subscription		name of the Azure subscription (no default)
	-d domain-name		IP domain name (default: internal.cloudapp.net)
	-i instance-type	name of the Azure VM instance type for database nodes (default: Standard_D4ds_v4)
	-p Oracle-port		port number of the Oracle TNS Listener (default: 1521)
	-r region		name of Azure region (default: westus2)
	-s ORACLE_SID		Oracle System ID (SID) value (default: oradb01)
	-u urn			URN from Azure marketplace (default: Oracle:Oracle-Database-Ee:12.2.0.1:12.2.20180725)
	-v                      set verbose output is true (default: false)
	-w SYS/SYSTEM pwd	initial password for Oracle database SYS and SYSTEM accounts (default: oracleA1)

## Usage notes:

	1) Azure subscription must be specified with "-S" switch, always

	2) Azure owner, default is output of "whoami" command in shell, can be specified using "-O" switch on command-line

	3) Azure project, default is "oradg", can be specified using "-P" switch on command-line

	4) Azure resource group, specify with "-G" switch or with a combination of "-O" (project owner tag) and "-P" (project name) values (default: "(project owner tag)-(project name)-rg").

	   For example, if the project owner tag is "abc" and the project name is "beetlejuice", then by default the resource group is expected to be named "abc-beetlejuice-rg", unless changes have been specified using the "-G", "-O", or "-P" switches

	5) Use the "-v" (verbose) switch to verify that program variables have the expected input values from the command-line

	6) For users who are expected to use prebuilt storage accounts and networking (i.e. vnet, subnet, network security groups, etc), consider using the "-N" switch to accept these as prerequisites 

	Please be aware that Azure owner (i.e. "-O") and Azure project (i.e. "-P") are used to generate names for the Azure resource group, storage account, virtual network, subnet, network security group and rules, VM, and storage disks.  Use the "-v" switch to verify expected naming.

	The "-N" and "-M" switches were mainly used for debugging, and might well be removed in more mature versions of the script.  They intended to skip over some steps if something failed later on.

## Testing DataGuard switchover and failover

To test the actions of "switchover" and "failover", SSH into the the "oracle" account of the "observer" VM and run the DGMGRL utility after connecting as the SYS database account using the TNS string "${DB_NAME}_dgmgrl".

For example, if the "${ORACLE_SID}" value is "oradg01", then the DB_NAME of the primary database on the first VM will also be "oradg01", while the DB_NAME of the standby database on the second VM will be "oradg01_stdby".

Therefore, starting from the Azure cloud shell where the "cr_oradg.sh" script was executed, perform the following steps to test switchover...

1. SSH into the "observer" VM using SSH public-key authentication via the administrative OS account
   - if the admin OS account is "tigorman" and the public IP address is "10.20.30.40", use "`ssh tigorman@10.20.30.40`"
2. Then, change from the administrative OS account to the "oracle" OS account
   - use "`sudo su - oracle`"
3. Initialize the ORACLE_SID environment variable
   - use "`export ORACLE_SID={value}`". For example, if the value of ORACLE_SID is "oradg01", then use "`export ORACLE_SID=oradg01`".
4. Login to the DataGuard Broker DGMGRL utility
   - use the command "`dgmgrl sys/{password}@{tns-string-for-dgmgrl}`"
   - where "{password}" is the password for the SYS database account set by the "cr_oradg.sh" script (default: "oracleA1")
   - where "{tns-string-for-dgmgrl}" is "{db-name}_dgmgrl"
      - where "db-name" is ORACLE_SID value for the primary database and "{ORACLE_SID}_stdby" for the standby database
      - if ORACLE_SID value is "oradg01", then use "oradg01_dgmgrl" for the primary and "oradg01_stdby_dgmgrl" for the standby
   - using the defaults cited above, "`dgmgrl sys/oracleA1@oradg01_dgmgrl`" will connect the DataGuard broker to the primary
5. Once connected to the DataGuard Broker DGMGRL utilty, show the DataGuard configuration status
   - at the "`DGMGRL>`" prompt, run "`show configuration`"
6. Once connected to broker utility, also show the Fast-Start Failover configuration status
   - at the "`DGMGRL>`" prompt, run "`show fast_start failover`"
7. If both "`show configuration`" and "`show fast_start failover`" display no warnings or errors...
   - switchover the PRIMARY role from "oradg01" on the first VM to "oradg01_stdby" on the second VM
   - when completed, "oradg01_stdby" will be PRIMARY and "oradg01" will be STANDBY
8. Switchover can be performed in either direction as desired; verify that databases are ready for switchover or failover using the DGMGRL commands "`show configuration`" or "`validate database {db-name};`" 
9. Failover can be triggered by performing `SHUTDOWN ABORT` on the database with the PRIMARY role
   - the failed former PRIMARY cannot become a STANDBY until it is manually mounted with `STARTUP MOUNT`
   - after the failed former PRIMARY has been manually mounted, it must be reinstated into the configuration in DGMGRL
      - use the command "`reinstate database {db-name}`" to complete reinstatement of the failed database as a standby
