//
// This is the main driver file for deploying each resource defined in the parameters.
// It is responsible for creating the Resource Group, Virtual Network, Subnet, NSG, Public IP, NIC, VM, and Data Disk.
// This script deployment is at subscription scope, hence individual resources need to have their scope defined
// to ensure they are created in the correct resource group.
//

targetScope = 'subscription'

@description('Name of the Resource Group')
param resourceGroupName string 

@description('Location')
param location string = 'centralindia'

@description('Oracle VM Image reference')
param oracleImageReference object

@description('List of virtual networks')
param virtualNetworks array

@description('List of network security groups')
param networkSecurityGroups array

@description('List of virtual machines')
param virtualMachines array

@description('Tags to be added to the resources')
param tags object = {}

@description('Optional. Enable telemetry via a Globally Unique Identifier (GUID).')
param enableTelemetry bool = true

@description('Optional. Enable telemetry via a Globally Unique Identifier (GUID).')
param telemetryPid string = ''


module rg 'br/public:avm/res/resources/resource-group:0.2.1' = {
  name: 'rg-${resourceGroupName}'
  scope: subscription()
  params: {
    name: resourceGroupName
    location: location
    enableTelemetry: false
    tags: tags
  }
}

// Create a list of virtual networks, based on parameter values.
module networks 'br/public:avm/res/network/virtual-network:0.1.1' = [for (vnet, i) in virtualNetworks: {
  name: '${vnet.virtualNetworkName}${i}'
  dependsOn: [ rg, nsgs ]
  scope: resourceGroup(resourceGroupName)
  params: {
    name: vnet.virtualNetworkName
    subnets: [ {
        name: vnet.subnetName
        addressPrefix: vnet.addressPrefix
        networkSecurityGroupResourceId: nsgs[0].outputs.resourceId
      }
    ]
    location: location
    addressPrefixes: vnet.addressPrefixes
    enableTelemetry: false
    tags: tags
  }
}
]

module nsgs 'br/public:avm/res/network/network-security-group:0.1.2' = [for (nsg, i) in networkSecurityGroups: {
  name: '${nsg.networkSecurityGroupName}${i}'
  dependsOn: [ rg ]
  scope: resourceGroup(resourceGroupName)
  params: {
    name: nsg.networkSecurityGroupName
    securityRules: nsg.securityRules
    location: location
    enableTelemetry: false
    tags: tags
  }
}]


// Create a set of VMs based on the supplied Oracle Image
module vms 'br/public:avm/res/compute/virtual-machine:0.1.0' = [for (vm, i) in virtualMachines: {
  name: vm.virtualMachineName
  dependsOn: [ networks ]
  scope: resourceGroup(resourceGroupName)
  params: {
    name: vm.virtualMachineName
    adminUsername: vm.adminUsername
    availabilityZone: vm.avZone
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: '128'
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    osType: 'Linux'
    publicKeys: [
      {
        keyData: vm.sshPublicKey
        path: '/home/${vm.adminUsername}/.ssh/authorized_keys'
      }
    ]
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            pipConfiguration: {
              publicIpNameSuffix: '-pip-01'
            }
            subnetResourceId: networks[0].outputs.subnetResourceIds[0]
          }
        ]
        nicSuffix: '-nic-01'
      }
    ]
    dataDisks: vm.dataDisks
    disablePasswordAuthentication: true
    vmSize: vm.vmSize
    location: location
    encryptionAtHost: false //revisit this
    enableTelemetry: false
    tags: tags
    imageReference: oracleImageReference
    //dataCollectionRuleId: !empty(dcrWorkspaceResourceId) ? dcr.outputs.dataCollectionRuleId : null
  }
}]

resource defaultTelemetry 'Microsoft.Resources/deployments@2023-07-01' = if (enableTelemetry) {
  name: 'pid-${telemetryPid}-${uniqueString(deployment().name, location)}'
  location: location
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
    }
  }
}
