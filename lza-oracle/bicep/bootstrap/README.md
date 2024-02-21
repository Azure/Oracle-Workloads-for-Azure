This folder contains bicep code for deploying 
- A Resource group
- Infrastructure components for implementing Oracle data guard and supporting resources

## Deployment steps

- There are 2 main folders - Single_instance and Data_guard.

    - Parameter files in Single_instance folder deploy a single Oracle VM, with other supporting resources such as Vnet, NICs etc
    
    - Parameter files in Data_guard folder deploy 3 Oracle VMs - a Primary , Secondary and Observer VMs, in separate Availability zones. All supporting resources can also be created if necessary.

    - The 'default' folder has an example parameter file which deploys only the essential resources - VMs, virtual networks and other components
    - The 'rbac' folder has an example parameter file which deploys additional role definitions for resources, as required.  The Users/service principals used in role definitions have to be deployed separately, and the ObjectID of the principals need to be added to the template.
    - The 'diagnostics' folder has example parameter files which deploys diagnostics settings for various resources, including MMA agent provisioning on the Oracle VMs. A Log analytics workspace needs to be deployed first, and the workspace Resource ID needs to be updated in the respective template. The README file in those folders contain instructions for deploying LA workspaces.

    At a minimum, the following values need to be changed in parameter files for a functional deployment:
    - Azure Region for deployment
    - Admin user name and SSH Public key for each VM
    - There are several other parameters which can be customized, including the VM SKU, Oracle image used, and so on.

- Change directory to ~/lza-oracle/bicep/bootstrap

### For Single instance:

```powershell
az deployment sub create --name demo --location centralindia --template-file main.bicep --parameters single_instance/default/single_instance.bicepparam
```

### For Data Guard:

```powershell
az deployment sub create --name demo --location centralindia --template-file main.bicep --parameters data_guard/default/data_guard.bicepparam
```

On an average - both the template deployments should complete in less than 5 minutes.