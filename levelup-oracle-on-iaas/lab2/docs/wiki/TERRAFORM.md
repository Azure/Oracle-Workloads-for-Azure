# Provisioning of Azure VM via Terraform




### How to deploy single VM for Oracle in the VNET

In this module, you will deploy single virtual machine in the virtual network.

<img src="../media/single_vm.png" />



Before using this module, you have to create your own ssh key to deploy and connect the virtual machine you will create. To do so, please follow the steps given below.



1. Do the following on the compute source:

```bash
ssh-keygen -f ~/.ssh/lza-oracle-single-instance

ls -lha ~/.ssh/

-rw-------   1 yourname  staff   2.6K  8 17  2023 lza-oracle-single-instance
-rw-r--r--   1 yourname  staff   589B  8 17  2023 lza-oracle-single-instance.pub
```

2. Next, you go to `terraform/bootstrap/single_instance` directory and create `fixtures.tfvars` file as follows. The contents of the ssh public key that you created in the previous step are copied to the new file.


```bash
cd ~/projects/Oracle-Workloads-for-Azure/levelup-oracle-on-iaas/lab2/terraform/bootstrap/single_instance
cat ~/.ssh/lza-oracle-single-instance.pub > fixtures.tfvars
```

3. Edit the file and modify it so that the format matches the following. Make sure to include the double quotes. 

```bash
nano  ~/projects/Oracle-Workloads-for-Azure/levelup-oracle-on-iaas/lab2/terraform/bootstrap/single_instance/fixtures.tfvars
```

Here is a sample `fixtures.tfvars` file.

```tf:fixtures.tfvars
ssh_key = "ssh-rsa xxxxxxxxxxxxxx="
```

<img src="../media/fixtures.jpg" />


4. Next, execute below Terraform commands. When you deploy resources to Azure, you have to indicate `fixtures.tfvars` as a variable file, which contains the ssh public key.

```
pwd

~/projects/Oracle-Workloads-for-Azure/levelup-oracle-on-iaas/lab2/terraform/bootstrap/single_instance

terraform init

terraform plan -var-file=fixtures.tfvars

terraform apply -var-file=fixtures.tfvars
```

(The "terraform plan" command should only take about 1-2 mins to run. If it takes any longer, interrupt the script and re-run).



(The "terraform apply" command will run for about 8-12 minutes.)

(When prompted for "Enter a value:" , type in "yes" and press Enter)

(If using Azure Cloud Shell, remember to refresh your browser by scrolling up or down, every 15 minutes or so since the shell times out after 20 minutes of inaction.)


5. (OPTIONAL) Finally, you can connect to the virtual machine with ssh private key. While deploying resources, a public ip address is generated and attached to the virtual machine, so that you can connect to the virtual machine with this IP address. The username is `oracle`, which is fixed in `terraform/bootstrap/single_instance/module.tf`.

```
ssh -i ~/.ssh/lza-oracle-single-instance  oracle@<PUBLIC_IP_ADDRESS>
```

6. Now you can go back to the main [README.md](../../README.md#step-by-step-instructions) file.


