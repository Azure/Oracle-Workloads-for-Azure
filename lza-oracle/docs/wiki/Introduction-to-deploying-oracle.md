# Background

This guide describes how to automate implementing Oracle on Azure VMs, either single-instance or configured in an Oracle Dataguard fail-over configuration. In the guide it is assumed that you will be using GitHub actions or manual deployment to implement virtual machines and associated components for your Oracle workload.

> Note that this is a preview solution intended to solicitate feedback for further development which should be tested in a safe environment before deploying to production to protect against possible failures/unnecessary cost. The solution is not intended to be used in production environments without thorough testing and validation. The solution is provided as-is and is not supported through any Microsoft support program or service. Please provide feedback through the GitHub issues list in this repository.

The repo at present contains code and details for the following:

- Terraform code to deploy a single-instance Oracle VM on Azure.
- Ansible code to configure the Oracle VM with one or more databases (Oracle Database Enterprise Edition 19c).
- A sample Github Actions workflow to deploy the Oracle VM and configure the databases.

The components are created as follows:

1. Virtual machine and associated components are created using Terraform in a specified resource group.
2. Ansible code subsequently needs to be run to configure the Oracle VM with one or more databases (Oracle Database Enterprise Edition 19c).

## Pre-requisites/limitations

1. An Azure subscription. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/en-us/free/?ref=microsoft.com&utm_source=microsoft.com&utm_medium=docs&utm_campaign=visualstudio) before you begin.
2. If deploying manually, you will require a compute source running Ubuntu. This can either be Azure Cloud Shell (recommended), a local computer or [an Azure VM](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/quick-create-portal?tabs=ubuntu).
3. If you are using either a local computer or an Azure VM, you need the following software installed on it. Github Action agents and Azure Cloud Shell have this software installed by default.
    1. If leveraging Terraform for Infrastructure-as-Code [Terraform](https://developer.hashicorp.com/terraform/downloads).
    1. If leveraging Bicep for Infrastructure-as-Code [Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) and [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.4)
    1. [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html).
    1. [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt).
4. Key vault or similar to manage public/private key pair for Oracle VM is not included in the code. You should create a key vault or similar and store the public/private key pair in that. Public key needs to be specified while deploying the virtual machines, either in a parameter file or from the command line.
5. Terraform state file is not stored in Azure. You will need to store the Terraform state file in a location of your choice.
6. The solution does not provide Oracle licensing, please ensure that you have sufficient Oracle licenses to deploy the solution.

## Getting started

- Fork this repo to your own GitHub organization, you should not create a direct clone of the repo. Pull requests based off direct clones of the repo will not be accepted.
- Clone the forked repo from your own GitHub organization to your developer workstation.
- Determine how you want to proceed with deployment, depending on what flavor of Oracle database VM you wish to deploy and the method you wish to use. See the section below for more details.

### Deploy through GitHub Actions (recommended method)

- [Single instance automated deployment with Terraform through GitHub Actions](./Deploy-SI-with-TF-GitHub-Actions.md) (recommended method)
- [Single instance automated deployment with Bicep through GitHub Actions](./Deploy-SI-with-Bicep-GitHub-Actions.md) (recommended method)
- [Dataguard automated deployment with Terraform through GitHub Actions](./Deploy-DG-with-TF-GitHub-Actions.md) (recommended method)
- [Dataguard automated deployment with Bicep through GitHub Actions](./Deploy-DG-with-Bicep-GitHub-Actions.md) (recommended method)
  
### Manual deployment

- [Single Instance manual deployment with Terraform through Azure CLI](./Deploy-SI-with-TF-Azure-CLI.md)
- [Single Instance manual deployment with Bicep through Azure CLI](./Deploy-SI-with-Bicep-Azure-CLI.md)
- [Dataguard manual deployment with Terraform through Azure CLI](./Deploy-DG-with-TF-Azure-CLI.md)
- [Dataguard manual deployment with Bicep through Azure CLI](./Deploy-DG-with-Bicep-Azure-CLI.md)
