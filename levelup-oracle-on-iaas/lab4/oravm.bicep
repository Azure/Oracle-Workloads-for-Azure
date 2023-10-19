@description('The name of you Virtual Machine.')
param vmName string = 'oravm'

@description('Username for the Virtual Machine.')
param adminUsername string

@description('SSH key for the Virtual Machine.')
param sshKey string

@description('The size of the VM')
param vmSize string = 'Standard_D2ds_v5'

@description('Availability zone')
param avZone string = '1'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Unique DNS Name for the Public IP used to access the Virtual Machine.')
param dnsLabelPrefix string = toLower('${vmName}-${uniqueString(resourceGroup().id)}')

@description('Resource ID of the subnet in the virtual network')
param subnetid string = 'Subnet'

@description('Name of the Network Security Group')
param networksecuritygroupid string = 'SecGroupNet'


var publicIPAddressName = '${vmName}PublicIP'
var networkInterfaceName = '${vmName}NetInt' 
var oracleImageReference =   {
  publisher: 'oracle'
  offer: 'oracle-database-19-3'
  sku: 'oracle-database-19-0904'
  version: 'latest'
}

var sshConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: sshKey
      }
    ]
  }
}


resource networkInterface 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: networkInterfaceName
  location: location
  
  properties: {
    enableAcceleratedNetworking: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetid
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddress.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: networksecuritygroupid
    }
  }
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: publicIPAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  zones:[avZone]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
    idleTimeoutInMinutes: 4
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  zones: [avZone]
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      dataDisks: [
        {
          caching: 'None'
          createOption: 'Empty'
          deleteOption: 'Delete'
          diskSizeGB: 128
          lun: 1
          managedDisk: {
            storageAccountType: 'Premium_LRS' 
          }
        }
      ]
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'           
        }
      }
      imageReference: oracleImageReference
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: sshConfiguration 
    }
    
  }
}

output vmManagedidentity string = vm.identity.principalId
