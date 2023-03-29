# oravm
Azure CLI (bash) script to fully automate the creation of an Azure VM to run Oracle database.

This script is based on a shell script authored by Kellyn Gorman.

## Description:

      Script to automate the creation of an Oracle database on a marketplace
      Oracle image within Microsoft Azure, using the Azure CLI.

      In addition to creating the VM with either managed disk or Azure NetApp Files storage,
      and an Oracle database on that VM, the script will also allocate an Azure Files share
      for archived redo log files, and enable Azure VM Backup.
      
## Examples of script usage

First of all, the "cr_oravm.sh" script expects to do all of its work within an Azure subscription and an Azure resource group.

The name of the Azure subscription has no default value, so the "-S" command-line switch followed by the name of the Azure subscription (possibly enclosed within double-quotes if the subscription name includes spaces) is always required...

    $ ./cr_oravm.sh -S MySubscriptionName

The name of the Azure resource group defaults to "{owner}-{project}-rg", where "{owner}" is the name of the OS account in which the script is being executed (i.e. output from "whoami" command) and "{project}" defaults to the string "oravm".  The "{owner}-{project}" string combination is used a lot within the script for naming objects like resource groups, VMs, storage, PPGs, etc.  So with this minimal call syntax, where only the name of the Azure subscription is specified, will result in the script expecting a resource group to already exist with the name of "{owner}-oravm-rg", where "{owner}" is the OS account name of the Azure CLI shell running the script.  For example, when the author uses "https://shell.azure.com", the resulting OS account name is "tim", so using this minimal call syntax for the "cr_oravm.sh" script means that it expects an Azure resource group named "tim-oravm-rg" to exist already, and it will create about 7-9 Azure objects with a prefix of "tim-oravm-".  If you don't want the resource group to be required to have this name, then both these basic values can be changed from the defaults using the "-O" and "-P" command-line switches, respectively...

    $ ./cr_oravm.sh -S MySubscriptionName -O test -P foobar

As a result, the name of the resource group will be expected to be "test-foobar-rg", and all of the Azure objects created within the resource group will also be named with the prefix string of "test-foobar-".  If the name of the resource group is something else (i.e. "MyResourceGroupName") but you'd like all of the objects created by the script to start with the prefix string "test-foobar-", then you can use the following call syntax...

    $ ./cr_oravm.sh -S MySubscriptionName -R MyResourceGroupName -O test -P foobar

As a result, the precreated resource group named "MyResourceGroupName" within the existing "MySubscriptionName" subscription will be populated with objects with names like "test-foobar-vm01", "test-foobar-vnet", "test-foobar-vnet", etc.

Please see the next section for a complete list of all of the command-line switches, what they control, and default values...

## Usage:

        cr_oravm.sh -G val -H val -N -O val -P val -S val -c val -d val -i val -n val -p val -r val -s val -u val -v -w val -z val

## Where:

        -G resource-group-name  name of the Azure resource group (default: \"{owner}-{project}-rg\")
        -H ORACLE_HOME          full path of ORACLE_HOME software (default: /u01/app/oracle/product/19.0.0/dbhome_1)
        -N                      skip network setup i.e. vnet, NSG, NSG rules (default: false)
        -O owner-tag            name of the owner to use in Azure tags (default: Linux 'whoami')
        -P project-tag          name of the project to use in Azure tags (default: oravm)
        -S subscription         name of the Azure subscription (no default)
        -c True|False           True is ReadWrite for OS / ReadOnly for data, False is None (default: True)
        -d domain-name          IP domain name (default: internal.cloudapp.net)
        -i instance-type        name of the Azure VM instance type (default: Standard_D4ds_v4)
        -n #data-disks          number of data disks to attach to the VM (default: 1)
        -p Oracle-port          port number of the Oracle TNS Listener (default: 1521)
        -r region               name of Azure region (default: westus)
        -s ORACLE_SID           Oracle System ID (SID) value (default: oradb01)
        -u urn                  Azure URN for the VM from the marketplace (default: Oracle:oracle-database-19-3:oracle-database-19-0904:19.3.1)
        -v                      set verbose output is true (default: false)
        -w password             clear-text value of initial SYS and SYSTEM password in Oracle database (default: oracleA1)
        -z data-disk-GB         size of each attached data-disk in GB (default: 4095)


### Expected prerequisites:
        1) Azure subscription, specify with "-S" switch, as explained
           above (default: none)

        2) Azure resource group, specify with "-G" switch or with a
           combination of "-O" (project owner tag) and "-P" (project name)
           values (default: "(project owner tag)-(project name)-rg").

           For example, if the project owner tag is "abc" and the project
           name is "beetlejuice", then by default the resource group is
           expected to be named "abc-beetlejuice-rg", unless changes have
           been specified using the "-G", "-O", or "-P" switches

        3) Use the "-v" (verbose) switch to verify that program variables
           have the expected values

        4) For users who are expected to use prebuilt storage accounts
           and networking (i.e. vnet, subnet, network security groups, etc),
           consider using the "-N" switch to accept these as prerequisites 

# Important note

If the command-line parameter for the number of dataDisks (i.e. "-n") is set to one or greater (default is "1"), then this script will allocate premium SSD with LRS redundancy.

If the command-line has "-n 0" (i.e. zero data disks) specified, then this script will instead allocate Azure NetApp Files (ANF) storage over NFS v4.1.

# Usage examples

For example, to create an E16ds v4 VM with four 2 TiB data disks on the Azure marketplace image for Oracle19c in the WestUS2 region, please try these command-line options...

      ./cr_oravm.sh \
            -v \
            -S "ExampleSubscriptionName" \
            -P ora19c \
            -i Standard_E16ds_v4 
            -n 2 \
            -z 1024 \
            -r westus2

This will have the following impact, besides generating the example output displayed in the "oravm_output.txt" file...

 - the "-v" switch will display all script variables values and parameter values at the beginning of the execution
 - set the Azure subscription used by the session
 - set the Azure "project" value to "ora19c", which will impact the naming of all objects and tags
 - build a VM sized at Standard_E16ds_v4 using the default Azure marketplace Oracle19c image with an OS disk and two data disks of 1 TiB in the West US 2 region.
 - please note that the marketplace Oracle19c image has ORACLE_HOME at a specific location

# Finding Azure marketplace images from Oracle

To locate Oracle images in the Azure marketplace, you can use the Azure CLI command as follows...

    $ az vm image list --offer Oracle --all --publisher Oracle --output table
    Architecture    Offer                 Publisher    Sku                      Urn                                                         Version
    --------------  --------------------  -----------  -----------------------  ----------------------------------------------------------  -------------
    x64             oracle-database       Oracle       oracle_db_12_2_0_1_ee    Oracle:oracle-database:oracle_db_12_2_0_1_ee:12.2.01        12.2.01
    x64             oracle-database       Oracle       oracle_db_12_2_0_1_se    Oracle:oracle-database:oracle_db_12_2_0_1_se:12.2.01        12.2.01
    x64             oracle-database       Oracle       oracle_db_21             Oracle:oracle-database:oracle_db_21:21.0.0                  21.0.0
    x64             oracle-database-19-3  Oracle       oracle-database-19-0904  Oracle:oracle-database-19-3:oracle-database-19-0904:19.3.1  19.3.1
    x64             Oracle-Database-Ee    Oracle       12.1.0.2                 Oracle:Oracle-Database-Ee:12.1.0.2:12.1.20170220            12.1.20170220
    x64             Oracle-Database-Ee    Oracle       18.3.0.0                 Oracle:Oracle-Database-Ee:18.3.0.0:18.3.20181213            18.3.20181213
    x64             Oracle-Database-se    Oracle       12.1.0.2                 Oracle:Oracle-Database-se:12.1.0.2:12.1.20170220            12.1.20170220
    x64             Oracle-Database-se    Oracle       18.3.0.0                 Oracle:Oracle-Database-se:18.3.0.0:18.3.20181213            18.3.20181213
    x64             Oracle-Linux          Oracle       6.10                     Oracle:Oracle-Linux:6.10:6.10.00                            6.10.00
    x64             Oracle-Linux          Oracle       6.8                      Oracle:Oracle-Linux:6.8:6.8.0                               6.8.0
    x64             Oracle-Linux          Oracle       6.8                      Oracle:Oracle-Linux:6.8:6.8.20190529                        6.8.20190529
    x64             Oracle-Linux          Oracle       6.9                      Oracle:Oracle-Linux:6.9:6.9.0                               6.9.0
    x64             Oracle-Linux          Oracle       6.9                      Oracle:Oracle-Linux:6.9:6.9.20190529                        6.9.20190529
    x64             Oracle-Linux          Oracle       7.3                      Oracle:Oracle-Linux:7.3:7.3.0                               7.3.0
    x64             Oracle-Linux          Oracle       7.3                      Oracle:Oracle-Linux:7.3:7.3.20190529                        7.3.20190529
    x64             Oracle-Linux          Oracle       7.4                      Oracle:Oracle-Linux:7.4:7.4.1                               7.4.1
    x64             Oracle-Linux          Oracle       7.4                      Oracle:Oracle-Linux:7.4:7.4.20190529                        7.4.20190529
    x64             Oracle-Linux          Oracle       7.5                      Oracle:Oracle-Linux:7.5:7.5.1                               7.5.1
    x64             Oracle-Linux          Oracle       7.5                      Oracle:Oracle-Linux:7.5:7.5.2                               7.5.2
    x64             Oracle-Linux          Oracle       7.5                      Oracle:Oracle-Linux:7.5:7.5.20181207                        7.5.20181207
    x64             Oracle-Linux          Oracle       7.5                      Oracle:Oracle-Linux:7.5:7.5.20190529                        7.5.20190529
    x64             Oracle-Linux          Oracle       7.5                      Oracle:Oracle-Linux:7.5:7.5.3                               7.5.3
    x64             Oracle-Linux          Oracle       7.6                      Oracle:Oracle-Linux:7.6:7.6.2                               7.6.2
    x64             Oracle-Linux          Oracle       7.6                      Oracle:Oracle-Linux:7.6:7.6.3                               7.6.3
    x64             Oracle-Linux          Oracle       7.6                      Oracle:Oracle-Linux:7.6:7.6.4                               7.6.4
    x64             Oracle-Linux          Oracle       7.6                      Oracle:Oracle-Linux:7.6:7.6.5                               7.6.5
    x64             Oracle-Linux          Oracle       77                       Oracle:Oracle-Linux:77:7.7.1                                7.7.1
    x64             Oracle-Linux          Oracle       77                       Oracle:Oracle-Linux:77:7.7.2                                7.7.2
    x64             Oracle-Linux          Oracle       77                       Oracle:Oracle-Linux:77:7.7.3                                7.7.3
    x64             Oracle-Linux          Oracle       77                       Oracle:Oracle-Linux:77:7.7.4                                7.7.4
    x64             Oracle-Linux          Oracle       77                       Oracle:Oracle-Linux:77:7.7.5                                7.7.5
    x64             Oracle-Linux          Oracle       77                       Oracle:Oracle-Linux:77:7.7.6                                7.7.6
    x64             Oracle-Linux          Oracle       77-ci                    Oracle:Oracle-Linux:77-ci:7.7.01                            7.7.01
    x64             Oracle-Linux          Oracle       77-ci                    Oracle:Oracle-Linux:77-ci:7.7.02                            7.7.02
    x64             Oracle-Linux          Oracle       77-ci                    Oracle:Oracle-Linux:77-ci:7.7.03                            7.7.03
    x64             Oracle-Linux          Oracle       78                       Oracle:Oracle-Linux:78:7.8.3                                7.8.3
    x64             Oracle-Linux          Oracle       78                       Oracle:Oracle-Linux:78:7.8.5                                7.8.5
    x64             Oracle-Linux          Oracle       79-gen2                  Oracle:Oracle-Linux:79-gen2:7.9.11                          7.9.11
    x64             Oracle-Linux          Oracle       79-gen2                  Oracle:Oracle-Linux:79-gen2:7.9.12                          7.9.12
    x64             Oracle-Linux          Oracle       79-gen2                  Oracle:Oracle-Linux:79-gen2:7.9.13                          7.9.13
    x64             Oracle-Linux          Oracle       79-gen2                  Oracle:Oracle-Linux:79-gen2:7.9.14                          7.9.14
    x64             Oracle-Linux          Oracle       79-gen2                  Oracle:Oracle-Linux:79-gen2:7.9.15                          7.9.15
    x64             Oracle-Linux          Oracle       79-gen2                  Oracle:Oracle-Linux:79-gen2:7.9.16                          7.9.16
    x64             Oracle-Linux          Oracle       79-gen2                  Oracle:Oracle-Linux:79-gen2:7.9.17                          7.9.17
    x64             Oracle-Linux          Oracle       79-gen2                  Oracle:Oracle-Linux:79-gen2:7.9.18                          7.9.18
    x64             Oracle-Linux          Oracle       79-gen2                  Oracle:Oracle-Linux:79-gen2:7.9.19                          7.9.19
    x64             Oracle-Linux          Oracle       79-gen2                  Oracle:Oracle-Linux:79-gen2:7.9.20                          7.9.20
    x64             Oracle-Linux          Oracle       79-gen2                  Oracle:Oracle-Linux:79-gen2:7.9.21                          7.9.21
    x64             Oracle-Linux          Oracle       79-gen2                  Oracle:Oracle-Linux:79-gen2:7.9.22                          7.9.22
    x64             Oracle-Linux          Oracle       79-gen2                  Oracle:Oracle-Linux:79-gen2:7.9.23                          7.9.23
    x64             Oracle-Linux          Oracle       79-gen2                  Oracle:Oracle-Linux:79-gen2:7.9.24                          7.9.24
    x64             Oracle-Linux          Oracle       79-gen2                  Oracle:Oracle-Linux:79-gen2:7.9.25                          7.9.25
    x64             Oracle-Linux          Oracle       79-gen2                  Oracle:Oracle-Linux:79-gen2:7.9.26                          7.9.26
    x64             Oracle-Linux          Oracle       79-gen2                  Oracle:Oracle-Linux:79-gen2:7.9.27                          7.9.27
    x64             Oracle-Linux          Oracle       8                        Oracle:Oracle-Linux:8:8.0.2                                 8.0.2
    x64             Oracle-Linux          Oracle       8-ci                     Oracle:Oracle-Linux:8-ci:8.0.11                             8.0.11
    x64             Oracle-Linux          Oracle       81                       Oracle:Oracle-Linux:81:8.1.0                                8.1.0
    x64             Oracle-Linux          Oracle       81                       Oracle:Oracle-Linux:81:8.1.2                                8.1.2
    x64             Oracle-Linux          Oracle       81-ci                    Oracle:Oracle-Linux:81-ci:8.1.0                             8.1.0
    x64             Oracle-Linux          Oracle       81-gen2                  Oracle:Oracle-Linux:81-gen2:8.1.11                          8.1.11
    x64             Oracle-Linux          Oracle       ol77-ci-gen2             Oracle:Oracle-Linux:ol77-ci-gen2:7.7.1                      7.7.1
    x64             Oracle-Linux          Oracle       ol77-gen2                Oracle:Oracle-Linux:ol77-gen2:7.7.01                        7.7.01
    x64             Oracle-Linux          Oracle       ol77-gen2                Oracle:Oracle-Linux:ol77-gen2:7.7.02                        7.7.02
    x64             Oracle-Linux          Oracle       ol77-gen2                Oracle:Oracle-Linux:ol77-gen2:7.7.03                        7.7.03
    x64             Oracle-Linux          Oracle       ol78-gen2                Oracle:Oracle-Linux:ol78-gen2:7.8.03                        7.8.03
    x64             Oracle-Linux          Oracle       ol78-gen2                Oracle:Oracle-Linux:ol78-gen2:7.8.05                        7.8.05
    x64             Oracle-Linux          Oracle       ol79                     Oracle:Oracle-Linux:ol79:7.9.1                              7.9.1
    x64             Oracle-Linux          Oracle       ol79                     Oracle:Oracle-Linux:ol79:7.9.10                             7.9.10
    x64             Oracle-Linux          Oracle       ol79                     Oracle:Oracle-Linux:ol79:7.9.11                             7.9.11
    x64             Oracle-Linux          Oracle       ol79                     Oracle:Oracle-Linux:ol79:7.9.12                             7.9.12
    x64             Oracle-Linux          Oracle       ol79                     Oracle:Oracle-Linux:ol79:7.9.13                             7.9.13
    x64             Oracle-Linux          Oracle       ol79                     Oracle:Oracle-Linux:ol79:7.9.14                             7.9.14
    x64             Oracle-Linux          Oracle       ol79                     Oracle:Oracle-Linux:ol79:7.9.2                              7.9.2
    x64             Oracle-Linux          Oracle       ol79                     Oracle:Oracle-Linux:ol79:7.9.25                             7.9.25
    x64             Oracle-Linux          Oracle       ol79                     Oracle:Oracle-Linux:ol79:7.9.26                             7.9.26
    x64             Oracle-Linux          Oracle       ol79                     Oracle:Oracle-Linux:ol79:7.9.27                             7.9.27
    x64             Oracle-Linux          Oracle       ol79                     Oracle:Oracle-Linux:ol79:7.9.3                              7.9.3
    x64             Oracle-Linux          Oracle       ol79                     Oracle:Oracle-Linux:ol79:7.9.4                              7.9.4
    x64             Oracle-Linux          Oracle       ol79                     Oracle:Oracle-Linux:ol79:7.9.5                              7.9.5
    x64             Oracle-Linux          Oracle       ol79                     Oracle:Oracle-Linux:ol79:7.9.6                              7.9.6
    x64             Oracle-Linux          Oracle       ol79                     Oracle:Oracle-Linux:ol79:7.9.7                              7.9.7
    x64             Oracle-Linux          Oracle       ol79                     Oracle:Oracle-Linux:ol79:7.9.8                              7.9.8
    x64             Oracle-Linux          Oracle       ol79                     Oracle:Oracle-Linux:ol79:7.9.9                              7.9.9
    x64             Oracle-Linux          Oracle       ol79-gen2                Oracle:Oracle-Linux:ol79-gen2:7.9.11                        7.9.11
    x64             Oracle-Linux          Oracle       ol79-lvm                 Oracle:Oracle-Linux:ol79-lvm:7.9.01                         7.9.01
    x64             Oracle-Linux          Oracle       ol79-lvm-gen2            Oracle:Oracle-Linux:ol79-lvm-gen2:7.9.11                    7.9.11
    x64             Oracle-Linux          Oracle       ol82                     Oracle:Oracle-Linux:ol82:8.2.1                              8.2.1
    x64             Oracle-Linux          Oracle       ol82                     Oracle:Oracle-Linux:ol82:8.2.3                              8.2.3
    x64             Oracle-Linux          Oracle       ol82-gen2                Oracle:Oracle-Linux:ol82-gen2:8.2.01                        8.2.01
    x64             Oracle-Linux          Oracle       ol83-lvm                 Oracle:Oracle-Linux:ol83-lvm:8.3.1                          8.3.1
    x64             Oracle-Linux          Oracle       ol83-lvm                 Oracle:Oracle-Linux:ol83-lvm:8.3.2                          8.3.2
    x64             Oracle-Linux          Oracle       ol83-lvm                 Oracle:Oracle-Linux:ol83-lvm:8.3.3                          8.3.3
    x64             Oracle-Linux          Oracle       ol83-lvm                 Oracle:Oracle-Linux:ol83-lvm:8.3.4                          8.3.4
    x64             Oracle-Linux          Oracle       ol83-lvm-gen2            Oracle:Oracle-Linux:ol83-lvm-gen2:8.3.11                    8.3.11
    x64             Oracle-Linux          Oracle       ol83-lvm-gen2            Oracle:Oracle-Linux:ol83-lvm-gen2:8.3.12                    8.3.12
    x64             Oracle-Linux          Oracle       ol83-lvm-gen2            Oracle:Oracle-Linux:ol83-lvm-gen2:8.3.13                    8.3.13
    x64             Oracle-Linux          Oracle       ol83-lvm-gen2            Oracle:Oracle-Linux:ol83-lvm-gen2:8.3.14                    8.3.14
    x64             Oracle-Linux          Oracle       ol84-lvm                 Oracle:Oracle-Linux:ol84-lvm:8.4.1                          8.4.1
    x64             Oracle-Linux          Oracle       ol84-lvm                 Oracle:Oracle-Linux:ol84-lvm:8.4.2                          8.4.2
    x64             Oracle-Linux          Oracle       ol84-lvm                 Oracle:Oracle-Linux:ol84-lvm:8.4.3                          8.4.3
    x64             Oracle-Linux          Oracle       ol84-lvm                 Oracle:Oracle-Linux:ol84-lvm:8.4.4                          8.4.4
    x64             Oracle-Linux          Oracle       ol84-lvm-gen2            Oracle:Oracle-Linux:ol84-lvm-gen2:8.4.11                    8.4.11
    x64             Oracle-Linux          Oracle       ol84-lvm-gen2            Oracle:Oracle-Linux:ol84-lvm-gen2:8.4.12                    8.4.12
    x64             Oracle-Linux          Oracle       ol84-lvm-gen2            Oracle:Oracle-Linux:ol84-lvm-gen2:8.4.13                    8.4.13
    x64             Oracle-Linux          Oracle       ol84-lvm-gen2            Oracle:Oracle-Linux:ol84-lvm-gen2:8.4.14                    8.4.14
    x64             Oracle-Linux          Oracle       ol85-lvm                 Oracle:Oracle-Linux:ol85-lvm:8.5.1                          8.5.1
    x64             Oracle-Linux          Oracle       ol85-lvm                 Oracle:Oracle-Linux:ol85-lvm:8.5.2                          8.5.2
    x64             Oracle-Linux          Oracle       ol85-lvm                 Oracle:Oracle-Linux:ol85-lvm:8.5.4                          8.5.4
    x64             Oracle-Linux          Oracle       ol85-lvm                 Oracle:Oracle-Linux:ol85-lvm:8.5.5                          8.5.5
    x64             Oracle-Linux          Oracle       ol85-lvm                 Oracle:Oracle-Linux:ol85-lvm:8.5.6                          8.5.6
    x64             Oracle-Linux          Oracle       ol85-lvm                 Oracle:Oracle-Linux:ol85-lvm:8.5.7                          8.5.7
    x64             Oracle-Linux          Oracle       ol85-lvm-gen2            Oracle:Oracle-Linux:ol85-lvm-gen2:8.5.11                    8.5.11
    x64             Oracle-Linux          Oracle       ol85-lvm-gen2            Oracle:Oracle-Linux:ol85-lvm-gen2:8.5.12                    8.5.12
    x64             Oracle-Linux          Oracle       ol85-lvm-gen2            Oracle:Oracle-Linux:ol85-lvm-gen2:8.5.14                    8.5.14
    x64             Oracle-Linux          Oracle       ol85-lvm-gen2            Oracle:Oracle-Linux:ol85-lvm-gen2:8.5.15                    8.5.15
    x64             Oracle-Linux          Oracle       ol85-lvm-gen2            Oracle:Oracle-Linux:ol85-lvm-gen2:8.5.16                    8.5.16
    x64             Oracle-Linux          Oracle       ol85-lvm-gen2            Oracle:Oracle-Linux:ol85-lvm-gen2:8.5.17                    8.5.17
    x64             Oracle-Linux          Oracle       ol86-lvm                 Oracle:Oracle-Linux:ol86-lvm:8.6.1                          8.6.1
    x64             Oracle-Linux          Oracle       ol86-lvm                 Oracle:Oracle-Linux:ol86-lvm:8.6.2                          8.6.2
    x64             Oracle-Linux          Oracle       ol86-lvm                 Oracle:Oracle-Linux:ol86-lvm:8.6.3                          8.6.3
    x64             Oracle-Linux          Oracle       ol86-lvm                 Oracle:Oracle-Linux:ol86-lvm:8.6.4                          8.6.4
    x64             Oracle-Linux          Oracle       ol86-lvm-gen2            Oracle:Oracle-Linux:ol86-lvm-gen2:8.6.1                     8.6.1
    x64             Oracle-Linux          Oracle       ol86-lvm-gen2            Oracle:Oracle-Linux:ol86-lvm-gen2:8.6.2                     8.6.2
    x64             Oracle-Linux          Oracle       ol86-lvm-gen2            Oracle:Oracle-Linux:ol86-lvm-gen2:8.6.3                     8.6.3
    x64             Oracle-Linux          Oracle       ol86-lvm-gen2            Oracle:Oracle-Linux:ol86-lvm-gen2:8.6.4                     8.6.4
    x64             Oracle-Linux          Oracle       ol8_2-gen2               Oracle:Oracle-Linux:ol8_2-gen2:8.2.13                       8.2.13
    x64             Oracle-Linux          Oracle       ol9-lvm                  Oracle:Oracle-Linux:ol9-lvm:9.0.1                           9.0.1
    x64             Oracle-Linux          Oracle       ol9-lvm-gen2             Oracle:Oracle-Linux:ol9-lvm-gen2:9.0.1                      9.0.1
    x64             oracle_sd-wan_edge    Oracle       oracle_sdwan_edge_91000  Oracle:oracle_sd-wan_edge:oracle_sdwan_edge_91000:8.4.0     8.4.0
    x64             oracle_virtual_esbc   Oracle       oracle_evsbc_84007       Oracle:oracle_virtual_esbc:oracle_evsbc_84007:8.4.0         8.4.0
    x64             oracle_virtual_esbc   Oracle       oracle_evsbc_90001       Oracle:oracle_virtual_esbc:oracle_evsbc_90001:9.0.0         9.0.0

If you remove all the entries for Oracle Linux standalone and Oracle WebLogic, leaving only Oracle database images, you might see something like this...

    $ az vm image list --offer Oracle-Database --all --publisher Oracle --output table
    Architecture    Offer                 Publisher    Sku                      Urn                                                         Version
    --------------  --------------------  -----------  -----------------------  ----------------------------------------------------------  -------------
    x64             oracle-database       Oracle       oracle_db_12_2_0_1_ee    Oracle:oracle-database:oracle_db_12_2_0_1_ee:12.2.01        12.2.01
    x64             oracle-database       Oracle       oracle_db_12_2_0_1_se    Oracle:oracle-database:oracle_db_12_2_0_1_se:12.2.01        12.2.01
    x64             oracle-database       Oracle       oracle_db_21             Oracle:oracle-database:oracle_db_21:21.0.0                  21.0.0
    x64             oracle-database-19-3  Oracle       oracle-database-19-0904  Oracle:oracle-database-19-3:oracle-database-19-0904:19.3.1  19.3.1
    x64             Oracle-Database-Ee    Oracle       12.1.0.2                 Oracle:Oracle-Database-Ee:12.1.0.2:12.1.20170220            12.1.20170220
    x64             Oracle-Database-Ee    Oracle       18.3.0.0                 Oracle:Oracle-Database-Ee:18.3.0.0:18.3.20181213            18.3.20181213
    x64             Oracle-Database-se    Oracle       12.1.0.2                 Oracle:Oracle-Database-se:12.1.0.2:12.1.20170220            12.1.20170220
    x64             Oracle-Database-se    Oracle       18.3.0.0                 Oracle:Oracle-Database-se:18.3.0.0:18.3.20181213            18.3.20181213

Reminder: the URN value (shown above) is what the "cr_oravm.sh" script expects as a value for the "-u" switch, just FYI?
