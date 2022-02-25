# Support for Oracle Database workloads within Azure Infrastructure-as-a-Service (IaaS)

This repository contains sub-folders representing multiple separate projects...

### 1. az-oracle-sizing
This project documents the method of sizing on-prem Oracle Database workloads for initial migration into Azure.  Too often, people capture the number of CPUs, amount of RAM, and quantity of storage configured to the on-prem infrastructure, and then they configure Azure resources based on those metrics.  Unfortunately, they don't know if the database was using all or just some of those allocated resources.  We focus on capturing actual observed information for:
1) observed CPU utilization
2) observed memory utilization
3) observed I/O utilization

...from standard Oracle AWR (automatic workload repository) reports, preferably generated during peak workload periods.  This project consists of documentation in PDF form, a sample MS-Excel spreadsheet for capturing the metrics needed from Oracle AWR reports.  The spreadsheet has two worksheets, the first to capture AWR information, and the second to generate estimates for choosing compute and storage resources from Azure.  This repository also holds an Oracle SQL\*Plus script named "dbspace.sql" which can be used to capture information not included in AWR reports, such as database size, table compression, volume of full and incremental RMAN backups, and daily volume of archived redo logs.

### 2. azbackup
This project relates to app-consistent Oracle database backups using Azure Backup.  Present is a bash-shell script for troubleshooting and training videos for configuring and restoring VMs supporting one or more Oracle database workloads.

### 3. oravm
This project contains an "accelerator" script for automating the creation of a single VM with a running Oracle database with integration to Azure Backup configured.  The bash-shell script "cr_oravm.sh" requires a subscription and a resource group as prerequisites, and within the resource group it builds a virtual net, a subnet, a network security group, as well as a VM with a NIC, public IP address, and storage using either premium SSD or Azure NetApp Files.  All is built automatically in about 30-35 minutes.  For more detailed information, please refer to the README within the folder.

### 4. oradg
This project contains an "accelerator" script for automating the creation of an Oracle DataGuard primary and standby database, each on separate VMs in separate availability zones, as well as a third VM with the Oracle DataGuard Broker observer.  The bash-shell script "cr_oradg.sh" requires a subscription and a resource group as prerequisites, and within the resource group it builds a virtual net, a subnet, a network security group, as well as three VMs with NICs, public IP addresses, and storage using premium SSD.  Everything is built automatically in about 40 minutes.  For more detailed information, please refer to the README within the folder.

### 5. orapcs
This project contains an "accelerator" script for automating the creation of Linux Pacemaker/Corosync (PCS) HA cluster for an Oracle database, with a database on shared storage maintained by two VMs within the same availability set and proximity placement group in a single availability zone, as well as a third VM intended as an observer.  The bash-shell script "cr_orapcs.sh" requires a subscription and a resource group as prerequisites, and within the resource group it builds a virtual net, a subnet, a network security group, as well as three VMs with NICs, public IP addresses, and storage using premium SSD.  Everything is built automatically in about 40 minutes.  For more detailed information, please refer to the README within the folder.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
