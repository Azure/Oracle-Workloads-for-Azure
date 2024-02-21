# Oracle Deployment Automation

## Overview

This repository contains code to install and configure Oracle databases on Azure VM for various scenarios in an automated fashion. The following scenarios are covered.

- A single VM with an Oracle database installed on it, deployed through Terraform and Ansible.
- Two VMs in an Oracle Dataguard configuration, deployed through Terraform and Ansible.

> Note that the code for doing the above in Bicep/Ansible is currently under development. Code for deploying via GitHub Actions is also under development.

## Step-by-step Instructions

For step by step instructions on how to deploy the above scenarios, please see the [deployment guide](docs/wiki/Introduction-to-deploying-oracle.md)

## Disclaimer

Please note that the code in this GitHub repository is currently in development and may be subject to frequent changes and updates. This means that the functionality and features of the code may change without notice. As such, you are advised to ensure that the code is tested thoroughly in a test environment before considering moving to production.

Additionally you are advised to reach out to the authors of this repository to discuss the code and its suitability for your environment, before deploying it in production. To do so create an issue [here](https://github.com/alz-oracle/issues), and we will get back to you as soon as possible.

By accessing or using the code in this repository, you agree to assume all risks associated with its use and to use it at your own discretion and risk. Microsoft shall not be liable for any damages or losses resulting from the use of this code. For support details, please see the [Support section](./SUPPORT.md).

## Wiki

Please see the content in the [wiki](docs/wiki/Home.md) for more detailed information about the repo and various other pieces of documentation.

## Known Issues

Please see the [Known Issues](docs/wiki/KnownIssues.md) in the wiki.

## Frequently Asked Questions

Please see the [Frequently Asked Questions](docs/wiki/FAQ.md) in the wiki.

## Contributing

This project welcomes contributions and suggestions. Most contributions require you to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us the rights to use your contribution. For details, visit [https://cla.opensource.microsoft.com](https://cla.opensource.microsoft.com).

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

> Details on contributing to this repo can be found [here in the wiki](docs/wiki/Contributing.md)

## Telemetry

When you deploy the IP located in this repo, Microsoft can identify the installation of said IP with the deployed Azure resources. Microsoft can correlate these resources used to support the software. Microsoft collects this information to provide the best experiences with their products and to operate their business. The telemetry is collected through customer usage attribution. The data is collected and governed by [Microsoft's privacy policies](https://www.microsoft.com/trustcenter).

If you don't wish to send usage data to Microsoft, or need to understand more about its' use details can be found [here](docs/wiki/Telemetry.md).

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party's policies.
