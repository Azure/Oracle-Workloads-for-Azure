using '../../main.bicep'

param resourceGroupName = 'oraGroup5'

param location = 'norwayeast'

param virtualNetworks = [
  {
    virtualNetworkName: 'vnet1'
    addressPrefixes: [
      '10.0.0.0/16' ]
    subnetName: 'subnet1'
    addressPrefix: '10.0.0.0/24'
  } ]

param networkSecurityGroups = [
  {
    networkSecurityGroupName: 'ora01nsg'
    securityRules: []
  }
]

param virtualMachines = [
  {
    virtualMachineName: 'vm-primary-0'
    vmSize: 'Standard_D4s_v5'
    avZone: 1
    adminUsername: 'oracle'
    sshPublicKey: '<sshKey>'
    dataDisks: [
      {
        caching: 'None'
        writeAcceleratorEnabled: false
        diskSizeGB: '1024'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      {
        caching: 'None'
        diskSizeGB: '1024'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      {
        name: 'redo'
        caching: 'ReadOnly'
        writeAcceleratorEnabled: false
        diskSizeGB: '1024'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    ]
  }
  {
    virtualMachineName: 'vm-secondary-0'
    vmSize: 'Standard_D4s_v5'
    avZone: 2
    adminUsername: 'oracle'
    sshPublicKey: '<sshKey>'
    dataDisks: [
      {
        caching: 'None'
        writeAcceleratorEnabled: false
        diskSizeGB: '1024'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      {
        caching: 'None'
        diskSizeGB: '1024'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      {
        name: 'redo'
        caching: 'ReadOnly'
        writeAcceleratorEnabled: false
        diskSizeGB: '1024'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    ]
  }
]

param tags = {
  environment: 'dev'
  costCenter: 'it'
}

param oracleImageReference = {
  publisher: 'oracle'
  offer: 'oracle-database-19-3'
  sku: 'oracle-database-19-0904'
  version: 'latest'
}


param enableTelemetry = true
param telemetryPid = '53df3afd-6e55-4930-a481-69938a5b8f0a'
