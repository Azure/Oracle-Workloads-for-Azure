# Introduction

The code is intended as an example for automated deployment of a single instance virtual machine with Oracle Database Enterprise Edition 19c using Github Actions. The code is intended to be used as a starting point for your own deployment. The module for this deployment is located in the `terraform/bootstrap/single_instance` directory.

 ![Single VM](media/single_vm.png)

## Variables

Overall if you wish to modify one or more variables in the module, you can do so by modifying the `terraform/bootstrap/single_instance/variables_global.tf`  or the `terraform/bootstrap/single_instance/variables_local.tf` file.

## Configure and run the workflow

First, configure your OpenID Connect as described [here](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure?tabs=azure-portal%2Cwindows#use-the-azure-login-action-with-openid-connect).

Create a Github Secret in your repo with the name SSH_PRIVATE_KEY, containing the private key you wish to use for the deployment.

To deploy through GitHub actions, please refer to the [Single instance GitHub Terraform workflow](../blob/main/.github/workflows/full-si-tf-deploy.yml) and follow the guidance below.

- Modify the following values in [Single instance GitHub Terraform workflow](../blob/main/.github/workflows/full-si-tf-deploy.yml):
  - Change _AZ_LOCATION: "eastus"_, to your preferred Azure region
  - Change _AZ_RG_BASENAME: "Oracle-test"_, to your preferred resource group name.
- Go to GitHub actions and run the action *Deploy single instance Oracle DB with Terraform*
