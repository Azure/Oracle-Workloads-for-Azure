# Lab 2: Deploying Oracle Landing Zone


## Overview

This repository describes how to create and install Oracle DB on an Azure VM in an automated fashion, through the use of "terraform" and "ansible".

A single Azure VM will be deployed in a VNET in your Azure subscription.

<img src="docs/media/single-instance-overview.png" />

## Pre-requisities

1. An Azure subscription. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/en-us/free/?ref=microsoft.com&utm_source=microsoft.com&utm_medium=docs&utm_campaign=visualstudio) before you begin.
2. A compute source running Ubuntu. This can either be a local computer, [Azure Cloud Shell](https://shell.azure.com)  or [an Azure VM](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/quick-create-portal?tabs=ubuntu). 
FOR THIS LAB => We strongly encourage the use of [Azure Cloud Shell](https://shell.azure.com) since all the required software such as Terraform, Ansible and Azure CLI are already installed.
3. Terraform installed on the compute source. Otherwise, follow the installations instructions [here](https://developer.hashicorp.com/terraform/downloads). It is already installed on the Azure Cloud Shell.
4. Ansible installed on the compute source. Otherwise, follow the installations instructions [here](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html). It is already installed on the Azure Cloud Shell.
5. Azure CLI installed on the compute source. Otherwise, follow the installations instructions [here](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt). It is already installed on the Azure Cloud Shell.


## Step-by-step Instructions

1. [Clone this repo](docs/wiki/CLONE.md) onto the compute resource.
2. [Provision infrastructure on Azure](docs/wiki/TERRAFORM.md) via terraform.
3. [Review the infrastructure](docs/wiki/REVIEW_INFRA.md) provisioned on Azure.
4. [Install and configure Oracle DB](docs/wiki/ANSIBLE.md) via ansible.
5. [Test the final configuration](docs/wiki/TEST.md).


## Disclaimer

Please note that the policies in this GitHub repository are currently in development and may be subject to frequent changes and updates. This means that the functionality and features of the polices may change without notice. As such, you are advised to ensure that the policies are tested thoroughly in a test environment before considering moving to production.

Additionally you are advised to reach out to the authors of this repository to discuss the policies and their suitability for your environment, before deploying them in production. To do so create an issue [here](https://github.com/alz-oracle/issues), and we will get back to you as soon as possible.

By accessing or using the code in this repository, you agree to assume all risks associated with its use and to use it at your own discretion and risk. Microsoft shall not be liable for any damages or losses resulting from the use of this code. For support details, please see the [Support section](./SUPPORT.md).


## Wiki

Please see the content in the [wiki](docs/wiki/Home.md) for more detailed information about the repo and various other pieces of documentation.

## Known Issues

Please see the [Known Issues](docs/wiki/KnownIssues.md) in the wiki.

## Frequently Asked Questions

Please see the [Frequently Asked Questions](docs/wiki/FAQ.md) in the wiki.

## Contributing


Please see the [Contributing](docs/wiki/Contributing.md) in the wiki.


## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
