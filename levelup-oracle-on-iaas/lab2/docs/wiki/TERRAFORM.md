# Provisioning of Azure VM via Terraform



## Prerequisites

1. Azure Active Directory Tenant.
2. Minimum 1 subscription, for when deploying VMs. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/en-us/free/?ref=microsoft.com&utm_source=microsoft.com&utm_medium=docs&utm_campaign=visualstudio) before you begin.

## Authenticate Terraform to Azure

To use Terraform commands against your Azure subscription, you must first authenticate Terraform to that subscription. [This doc](https://learn.microsoft.com/en-us/azure/developer/terraform/authenticate-to-azure?tabs=bash) describes how to authenticate Terraform to your Azure subscription.



### How to deploy single VM for Oracle in the VNET

In this module, you will deploy single virtual machine in the virtual network.

<img src="../media/single_vm.png" />



Before using this module, you have to create your own ssh key to deploy and connect the virtual machine you will create. To do so, please follow the steps given below.



1. Do the following on the compute source:

```bash
$ ssh-keygen -f ~/.ssh/lza-oracle-single-instance

$ ls -lha ~/.ssh/
-rw-------   1 yourname  staff   2.6K  8 17  2023 lza-oracle-single-instance
-rw-r--r--   1 yourname  staff   589B  8 17  2023 lza-oracle-single-instance.pub
```

2. Next, you go to `terraform/bootstrap/single_instance` directory and create `fixtures.tfvars` file as follows. The contents of the ssh public key that you created in the previous step are copied to the new file.


```bash
$ cd ~/projects/Oracle-Workloads-for-Azure/levelup-oracle-on-iaas/lab2/terraform/bootstrap/single_instance
$ cat ~/.ssh/lza-oracle-single-instance.pub > fixtures.tfvars
```

3. Edit the file and modify it so that the format matches the following. Make sure to include the double quotes. 

```bash
$ nano  ~/projects/Oracle-Workloads-for-Azure/levelup-oracle-on-iaas/lab2/terraform/bootstrap/single_instance/fixtures.tfvars
```

Here is a sample `fixtures.tfvars` file.

```tf:fixtures.tfvars
ssh_key = "ssh-rsa xxxxxxxxxxxxxx="
```

<img src="../media/fixtures.jpg" />


4. Next, execute below Terraform commands. When you deploy resources to Azure, you have to indicate `fixtures.tfvars` as a variable file, which contains the ssh public key.

```
$ pwd
~/projects/Oracle-Workloads-for-Azure/levelup-oracle-on-iaas/lab2/terraform/bootstrap/single_instance

$ terraform init

$ terraform plan -var-file=fixtures.tfvars

$ terraform apply -var-file=fixtures.tfvars
```

(When prompted for "Enter a value:" , type in "yes" and press Enter)

(The "terraform plan" section should only take about 1-2 mins to run. If it takes any longer, interrupt the script and re-run).

(If using Azure Cloud Shell, remember to refresh your browser by scrolling up or down, every 15 minutes or so since the shell times out after 20 minutes of inaction.)


5. (OPTIONAL) Finally, you can connect to the virtual machine with ssh private key. While deploying resources, a public ip address is generated and attached to the virtual machine, so that you can connect to the virtual machine with this IP address. The username is `oracle`, which is fixed in `terraform/bootstrap/single_instance/module.tf`.

```
$ ssh -i ~/.ssh/lza-oracle-single-instance  oracle@<PUBLIC_IP_ADDRESS>
```

6. Now you can go back to the main [README.md](../../README.md#step-by-step-instructions) file.



### How to enable diagnostic settings

To enable diagnostic settings, you have to set `is_diagnostic_settings_enabled` **true** in **common_infrastructure** module.

```
module "common_infrastructure" {
  source = "../../../terraform_units/modules/common_infrastructure"

  infrastructure                 = local.infrastructure
  is_diagnostic_settings_enabled = true  // ← This one
}
```

### How to assign roles in a specific scope

To assign roles, you must set `role_assignments` value in each module.

For example, in order to assign `Contributor` role in a subscription scope, you have to set the value like below.

```
module "common_infrastructure" {
  source = "../../../terraform_units/modules/common_infrastructure"

  ・・・

  role_assignments = {
    role_assignment_1 = {
      name                             = "Contributor"
      skip_service_principal_aad_check = false
    }
  }
}
```

Also, you can assign roles in the specific scope. If you want to assign `Virtual Machine Contributor` role in the VM scope, you should set the below value.

```
module "vm" {
  source = "../../../terraform_units/modules/compute"
  ・・・
  role_assignments = {
    role_assignment_1 = {
      name                             = "Virtual Machine Contributor"
      skip_service_principal_aad_check = false
    }
  }
}
```

Role names you can assign can be referred in [this document](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles).

### How to prevent from deleting resources accidentally

In order to prevent from deleting resources accidentally, you can lock resources in the specific scope.
If you want to enable resource locks, you can add resource lock variables in the specific module.

For example, you can enable resource lock at subscription level like this in `terraform/bootstrap/single_instance_module.tf` file.

```
module "common_infrastructure" {
  source = "../../../terraform_units/modules/common_infrastructure"

  ・・・

  subscription_locks = {
    name = "subscription_lock"
    type = "CanNotDelete"
  }
}
```

In addition to that, you can lock the specific resource. For example, if you consider enabling lock a virtual network, you can set the variable in `terraform/bootstrap/single_instance_module.tf` file.

```
module "network" {
  source = "../../../terraform_units/modules/network"

  ・・・

  vnet_locks = {
    name = "vnet_lock"
    type = "CanNotDelete"
  }
}
```

When you intend authorized users can only read from a resource, but they can't modify or delete it, you can set lock type `ReadOnly`.

### Note

#### Lun numbers of managed disks

This is the default lun nubmer of managed disks.

|           |     |
| :-------- | :-- |
| Data disk | 20  |
| ASM disk  | 10  |
| Redo disk | 60  |

We set these as default values in ansible part.

```
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
