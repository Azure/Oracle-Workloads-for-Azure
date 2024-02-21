# Introduction

The code is intended as an example for deployment of a single instance virtual machine with Oracle Database Enterprise Edition 19c. The code is intended to be used as a starting point for your own deployment. The module for this deployment is located in the `terraform/bootstrap/single_instance` directory.

![Single VM](media/single_vm.png)

## Deployment steps

- To use Terraform commands against your Azure subscription, you must first authenticate Terraform to that subscription. [This doc](https://learn.microsoft.com/en-us/azure/developer/terraform/authenticate-to-azure?tabs=bash) describes how to authenticate Terraform to your Azure subscription.

### SSH Key

Before using this module, you have to create your own ssh key to deploy and connect the virtual machine you will create. To do this follow these steps on your compute source:

```bash
ssh-keygen -f ~/.ssh/lza-oracle-single-instance
```

Verify that the key has been created:

```bash
ls -lha ~/.ssh/
```

The above command should result in output similar to the following:

```bash
-rw-------   1 yourname  staff   2.6K  8 17  2023 lza-oracle-single-instance
-rw-r--r--   1 yourname  staff   589B  8 17  2023 lza-oracle-single-instance.pub
```

Run the following commands to include the public key in the fixtures.tfvars file where it will be used when deploying the virtual machine:

```bash
pubkey="$HOME/.ssh/lza-oracle-single-instance.pub"
key_content=$(awk -F= '{print $1 FS}' "$pubkey")
fixtures="ssh_key = \"$key_content\""
echo $fixtures > <THIS_REPO>/terraform/bootstrap/single_instance/fixtures.tfvars
```

The fixtures.tfvars file should now contain the public key, see below for an example:

![fixtures](media/fixtures.jpg)

### Deploy the virtual machine

Perform the following steps to deploy the virtual machine:

- Verify that you are in the `terraform/bootstrap/single_instance` directory.
- Run the following commands to initialize Terraform state and deploy the virtual machine:

> To avoid registering unnecessary providers, you have to export the environment variable `ARM_SKIP_PROVIDER_REGISTRATION` as `true`.

```bash
export ARM_SKIP_PROVIDER_REGISTRATION=true
terraform init
terraform plan -var-file=fixtures.tfvars
terraform apply -var-file=fixtures.tfvars
```

### Connect to the virtual machine

Finally, you can connect to the virtual machine with ssh private key. While deploying resources, a public ip address is generated and attached to the virtual machine, so that you can connect to the virtual machine with this IP address. The username is `oracle`, which is hardcoded in `terraform/bootstrap/single_instance/module.tf`.

As the deployment enables Just-in-Time VM access, you will need to request access to the VM before you can connect to it as described [here](https://learn.microsoft.com/en-us/azure/defender-for-cloud/just-in-time-access-usage#enable-jit-on-your-vms-from-microsoft-defender-for-cloud).

Once the VM is accessible, you can connect to it with the following command:

```bash
ssh -i ~/.ssh/lza-oracle-single-instance  oracle@<PUBLIC_IP_ADDRESS>
```

Next step is to proceed with Ansible configuration to get the Oracle database operational. See the [Ansible single instance documentation](ANSIBLE-SI.md) for more details.

## Optional Settings

There are a number of optional settings which the module enables. These are described below. Overall if you wish to modify one or more variables in the module, you can do so by modifying the `terraform/bootstrap/single_instance/variables_global.tf` or the `terraform/bootstrap/single_instance/variables_local.tf` file.

### How to enable diagnostic settings

To enable diagnostic settings, you have to set `is_diagnostic_settings_enabled` **true** in **common_infrastructure** module.

```terraform
module "common_infrastructure" {
  source = "../../../terraform_units/modules/common_infrastructure"

  infrastructure                 = local.infrastructure
  is_diagnostic_settings_enabled = true  // ← This one
}
```

### How to assign roles in a specific scope

To assign roles, you must set `role_assignments` value in each module.

For example, in order to assign `Contributor` role in a subscription scope, you have to set the value like below.

```terraform
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

```terraform
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

```terraform
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

```terraform
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
