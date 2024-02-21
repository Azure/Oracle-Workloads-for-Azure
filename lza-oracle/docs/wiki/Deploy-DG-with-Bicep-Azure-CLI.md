# Introduction

The code is intended as an example for deployment of two Azure Virtual Machines with Oracle Database Enterprise Edition 19c in a Data Guard configuration. The code is intended to be used as a starting point for your own deployment. The Bicep module for this deployment is the `bicep/bootstrap/main.bicep` file.

 ![Data Guard configuration](media/dg_vms.png)

### Preparations

Before using this module, you have to create your own ssh key to deploy and connect to the virtual machines you will create. To do this follow these steps on your compute source:

```bash
ssh-keygen -f ~/.ssh/lza-oracle-data-guard
```

Verify that the key has been created:

```bash
ls -lha ~/.ssh/
```

The above command should result in output similar to the following:

```bash
-rw-------   1 yourname  staff   2.6K  8 17  2023 lza-oracle-data-guard
-rw-r--r--   1 yourname  staff   589B  8 17  2023 lza-oracle-data-guard.pub
```

Run the following command to get the public key:

```bash
cat .ssh/lza-oracle-data-guard.pub
```

Copy the output to the clipboard and paste into the `bicep/bootstrap/data_guard/default/data_guard.bicepparam` file in the `sshPublicKey` parameter.
Additonal parameters you may wish to modify such as location, resource group name, virtual machine name, etc. can also be modified in this file.

## Deployment steps

- Log on to Azure with an account that has the appropriate permissions to create resources in the subscription you wish to deploy to.
- From the root of the directory run the following command:

```bash
az deployment sub create --name OracleDG --location <Region you wish to deploy to> --template-file main.bicep --parameters data_guard/default/data_guard.bicepparam
```

## Enable Just-In-Time VM Access

After deploying and before connecting to the VMs, you need to enable Just-In-Time VM Access. To do this, follow these steps:

- To enable JIT VM Access, follow the guidance described [here](https://learn.microsoft.com/en-us/azure/defender-for-cloud/just-in-time-access-usage#enable-jit-on-your-vms-using-powershell). Note that you only need to include port 22, not 3389 in the policy.
- To request access to the VM, follow the guidance described [here](https://learn.microsoft.com/en-us/azure/defender-for-cloud/just-in-time-access-usage#request-access-to-a-jit-enabled-vm-using-powershell).

### Connect to the virtual machine (optional)

Finally, you can connect to the virtual machines with ssh private key. While deploying resources, a public ip address is generated and attached to the virtual machine, so that you can connect to the virtual machine with this IP address. The default username is `oracle`, as specified in `bicep/bootstrap/data_guard/default/data_guard.bicepparam` file in the `adminUsername` parameter.

Once the VMs are accessible and JIT configured, you can connect to them with the following command:

```bash
ssh -i ~/.ssh/lza-oracle-data-guard  oracle@<PUBLIC_IP_ADDRESS_primary>
ssh -i ~/.ssh/lza-oracle-data-guard  oracle@<PUBLIC_IP_ADDRESS_secondary>
```

Next step is to proceed with Ansible configuration to get the Oracle database operational. See the [Ansible Data Guard documentation](ANSIBLE-DG.md) for more details.

## Optional Settings


fixme to update

### Note
fixme to verify
#### Lun numbers of managed disks

This is the default lun nubmer of managed disks.

|           |     |
| :-------- | :-- |
| Data disk | 20  |
| ASM disk  | 10  |
| Redo disk | 60  |

We set these as default values in ansible part.

```ansible
  - name: Get ASM Disks
    shell: "cd /dev/disk/azure/scsi1 ; lunpath=`ls /dev/disk/azure/scsi1 | grep -e lun[1][0-9]$` ; readlink -f ${lunpath}"
    become_user: root
    register: asm_disks
  - name: Get Data Disks
    shell: "cd /dev/disk/azure/scsi1 ; lunpath=`ls /dev/disk/azure/scsi1 | grep -e lun[2,3,4,5][0-9]$` ; readlink -f ${lunpath}"
    become_user: root
    register: data_disks
  - name: Get Redo Disks
    shell: "cd /dev/disk/azure/scsi1 ; lunpath=`ls /dev/disk/azure/scsi1 | grep -e lun[6][0-9]$` ; readlink -f ${lunpath}"
    become_user: root
    register: redo_disks
```
