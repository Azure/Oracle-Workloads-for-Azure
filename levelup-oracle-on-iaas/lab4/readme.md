# Lab 4: Implement High Availability for Oracle on Azure Using DataGuard

This is a (partial) adaptation of the Oracle Data guard implementation avavilable here, converted into Bicep/Azure Resource Manager templates:
https://github.com/Azure/Oracle-Workloads-for-Azure/tree/main/oradg 

This template deploys the following resources:

- Primary Oracle Database VM with a data disk
- Secondary Oracle Database VM with a data disk
- Observer VM 

## Bicep Modules: 

- Main.bicep : this is the driver script for deploying resources
- Oravm.bicep : this module includes the resources for creating the VM such as Public-IP , Data disk etc, and also creates the VM resource based on Oracle Marketplace image.
- Customscript.bicep : this module wrips custom script execution on the respective VM

## Sequence of operations: 

- Provisioning of VMs
- Primary DB VM configuration (primary.sh)
    - File system creation
    - Oracle DB creation and configuration
    - Modifying Oracle config files incouding tnsnames.ora and listener.ora
    - Disable VM firewall (such that replication can happen between primary and secondary)
- Secondary DB VM configuration (secondary.sh)
    - File system creation
    - Create Oracle duplicate DB through DBCA
    - Modifying Oracle config files including tnsnames.ora and listener.ora
- Observer VM configuration (observer.sh)
    - Data Guard configuration
    - Fast Start failover configuration 
    - Start of Observer component 

## Prerequisites  

- A valid Azure subscription with at least contributor privileges
- Quota available for atleast 10 vCPUs (4 each for Primary and secondary, 2 for Observer) in the selected azure region. The default VM SKU is Standard_D4ds_v5 for Primary/Secondary, and Standard_D2ds_v5 for observer. Any other General purpose series of similar configuration can be substituted - such as Ddsv4, Dasv4 or Dasv5
- Latest Azure CLI installed 
- A valid ssh key pair. https://learn.microsoft.com/en-us/azure/virtual-machines/linux/mac-create-ssh-keys 

## How to deploy the template 

- Clone this repo

```powershell
git clone https://github.com/Azure/Oracle-Workloads-for-Azure.git 
```

- Modify the main.bicepparam file, with admin username for the Oracle VM, and the ssh public key. The public key should be in ~/.ssh/id_rsa.pub by default.

- If the VM size needs to be customized, add a parameter for VMsize in main.bicepparam. example:

```powershell
param vmSize = 'Standard_D4ds_v4'
``` 

- Login to Azure CLI (if not in Cloud shell)

- Deploy a resource group in your preferred region, where quota is available 

```powershell
 az group create --resource-group oragroup --location centralindia
 ```

- Deploy the template using the following command 

```powershell
 az deployment group create --resource-group oragroup --template-file main.bicep --parameters main.bicepparam
```

- Deployment progress can be viewed in Azure Portal. (Portal -> Resource group -> Deployments). Custom script logs are written in each VM by default  to the directory:  /var/lib/waagent/custom-script/download/0/ . The complete deployment should take about ~20 mins.

## How to verify the deployment 

- Verify if template deployment is fully successful, without any errors.
- Login to the Observer node, using ssh. Please note that if JIT policy is enabled on your VM automatically, you have to Request access before running ssh. 

```powershell
ssh <adminusername>@<observeripaddress>
```

- Sudo into the Oracle account

```powershell
sudo su - oracle
```

- Run Data guard command line utility. Messages similar to following will be displayed

```powershell
[oracle@observer ~]$ dgmgrl sys/oracleA1@oradb01_dgmgrl
DGMGRL for Linux: Release 19.0.0.0.0 - Production on Sun Oct 15 16:03:04 2023
Version 19.3.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

Welcome to DGMGRL, type "help" for information.
Connected to "oradb01"
Connected as SYSDBA.
```

- Run 'show configuration' command in DG command line utility

```powershell
DGMGRL> show configuration;

Configuration - FSF

  Protection Mode: MaxAvailability
  Members:
  oradb01 - Primary database
    oradb02 - (*) Physical standby database

Fast-Start Failover: Enabled in Zero Data Loss Mode

Configuration Status:
SUCCESS   (status updated 43 seconds ago)

DGMGRL>
```

Output similar to above should be displayed. This means that Data guard has been deployed, with Fast-start Failover enabled and set to Maximum availability.



