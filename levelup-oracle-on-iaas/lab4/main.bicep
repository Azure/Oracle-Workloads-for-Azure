@description('Username for the Virtual Machine.')
param adminUsername string

@description('SSH key for the Virtual Machine.')
param sshKey string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('The size of the VM')
param vmSize string = 'Standard_D4ds_v5'

@description('The size of the Observer VM')
param observerVMSize string = 'Standard_D2ds_v5'

@description('Name of the VNET')
param virtualNetworkName string = 'vNet'

@description('Name of the subnet in the virtual network')
param dbSubnetName string = 'Subnet'

@description('Name of the Network Security Group')
param networkSecurityGroupName string = 'SecGroupNet'

@description('Primary Oracle SID')
param primaryOracleSid string = 'oradb01'

@description('Secondary Oracle SID')
param secondaryOracleSid string = 'oradb02'

@description('Primary VM name')
param primaryVMName string = 'primary'

@description('Secondary VM name')
param secondaryVMName string = 'secondary'

@description('Observer VM name')
param observerVMName string = 'observer'

@description('Oracle SYS password')
@secure()
param oracleSysPassword string

@description('Oracle Mount directory')
param oracleMountDirectory string = '/u02'

var subnetAddressPrefix = '10.1.0.0/24'
var addressPrefix = '10.1.0.0/16'

var primaryvmscript = loadTextContent('primary.sh')
var secondaryvmscript = loadTextContent('secondary.sh')
var observervmscript = loadTextContent('observer.sh')


resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  parent: virtualNetwork
  name: dbSubnetName
  properties: {
    addressPrefix: subnetAddressPrefix
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}
module primary './oravm.bicep' = {
  name: 'primary'
  params: {
    vmName: primaryVMName
    location: location
    adminUsername: adminUsername
    sshKey: sshKey
    subnetid: subnet.id
    networksecuritygroupid: networkSecurityGroup.id
    avZone: '1' 
    vmSize: vmSize
  }
}


module secondary './oravm.bicep' = {
  name: 'secondary'
  params: {
    vmName: secondaryVMName
    location: location
    adminUsername: adminUsername
    sshKey: sshKey
    subnetid: subnet.id
    networksecuritygroupid: networkSecurityGroup.id
    avZone: '2'     
    vmSize: vmSize
  }
}

module observer './oravm.bicep' = {
  name: 'observer'
  params: {
    vmName: observerVMName
    location: location
    adminUsername: adminUsername
    sshKey: sshKey
    subnetid: subnet.id
    networksecuritygroupid: networkSecurityGroup.id
    avZone: '2'     
    vmSize: observerVMSize
  }
}

// Setup parameters to be passed to script
var varFile = loadTextContent('variables.txt')
var scriptVariables = replace(replace(replace(replace(replace(replace(replace(varFile,'<primaryOracleSid>',primaryOracleSid), '<secondaryOracleSid>', secondaryOracleSid),'<primaryVMName>', primaryVMName),'<secondaryVMName>',secondaryVMName),'<observerVMName>',observerVMName),'<oracleSysPassword>',oracleSysPassword),'<oracleMountDirectory>',oracleMountDirectory)


//Configure Primary database VM, after all components are provisioned
module vmonescript 'customscript.bicep' = {
  name: 'vmonescript'
   dependsOn: [primary,secondary,observer]
  params: {
   scriptName: 'primary1'
   vmName: primary.name
   location: location
   scriptContent: base64(replace(primaryvmscript,'#<insertVariables>',scriptVariables))
  }
}

//Configure secondary database VM, after primary VM is configured successfully
module vmtwoscript 'customscript.bicep' = {
  name: 'vmtwoscript'
  dependsOn: [vmonescript]
  params: {
   scriptName: 'secondary1'
   vmName: secondary.name
   location: location
   scriptContent: base64(replace(secondaryvmscript,'#<insertVariables>',scriptVariables))
  }
}

//Configure observer VM, after primary and secondary VM are configured successfully
module vmthreescript 'customscript.bicep' = {
  name: 'vmthreescript'
  dependsOn: [vmtwoscript]
  params: {
   scriptName: 'observer1'
   vmName: observer.name
   location: location
   scriptContent: base64(replace(observervmscript,'#<insertVariables>',scriptVariables))
  }
}

