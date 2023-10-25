# Cloning the repo

## Getting started

- Fork this repo to your own GitHub organization, you should not create a direct clone of the repo. Pull requests based off direct clones of the repo will not be allowed.
- Clone the repo from your own GitHub organization to your developer workstation.
- Review your current configuration to determine what scenario applies to you. We have guidance that will help deploy Oracle VMs in your subscription.


Follow the steps given below:

1. Login to the local compute resource running Ubuntu. If using Azure Cloud Shell, login to  [Azure Cloud Shell](https://shell.azure.com).

2. Install "pip". If you are using Azure Cloud Shell, then ignore this step.
```
$ sudo apt update
$ sudo apt install python3-pip
```

3. Create a subdirectory to clone the repo.
```
$ mkdir ~/projects
$ cd projects
```

4. Start cloning the repo.
```
$ git clone https://github.com/Azure/Oracle-Workloads-for-Azure.git 
```

5. Now you can go back to the main [README.md](../../README.md#step-by-step-instructions) file.
