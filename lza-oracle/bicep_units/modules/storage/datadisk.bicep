metadata name = 'datadisk'
metadata description = 'This module provisions a data disk and attaches it to a given VM'
metadata owner = 'Azure/module-maintainers'

//import * as avmtypes from '../common_infrastructure/common_types.bicep'

@description('Disk name')
param diskName string

@description('Disk size')
param diskSize int

@description('Location')
param location string = resourceGroup().location

@description('The type of storage account')
param diskType string = 'Premium_ZRS' // AVM req: Resources should be at highest possible resiliency

@description('Availability zone')
param avZone int = 1

//param diskResourcePrefix string

// @description('Optional. The lock settings of the service.')
// param lock  string

// @description('Optional. Array of role assignment objects that contain the \'roleDefinitionIdOrName\' and \'principalId\' to define RBAC role assignments on this resource. In the roleDefinitionIdOrName attribute, you can provide either the display name of the role definition, or its fully qualified ID in the following format: \'/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11\'.')
// param roleAssignments string

@description('Optional. Enable telemetry via a Globally Unique Identifier (GUID).')
param enableTelemetry bool = true

@description('Tags to be added to the resources')
param tags object = {}

//var dataDiskName = '${diskResourcePrefix}-${diskName}'

// Data disks are pinned to an Availability zone.
// Parameters should be defined correctly so that the data disk is pinned to the same zone as the VM.
resource data_disk 'Microsoft.Compute/disks@2023-04-02' = {
  name: diskName
  location: location
  sku: { name: diskType }
  zones: [ '${avZone}' ]
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: diskSize

  }
  tags: tags
}


// resource dataDiskLock 'Microsoft.Authorization/locks@2016-09-01' = if (!empty(lock ?? {}) && lock.?kind != 'None') {
//   name: lock.?name ?? 'lock-${dataDiskName}'
//   properties: {
//     level: lock.?kind ?? ''
//     notes: lock.?kind == 'CanNotDelete' ? 'Cannot delete resource or child resources.' : 'Cannot delete or modify the resource or child resources.'
//   }
//   scope: data_disk
// }

// resource dataDiskRoleAssignments 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for (roleAssignment, index) in (roleAssignments ?? []): {
//   name: guid(data_disk.id, roleAssignment.principalId, roleAssignment.roleDefinitionIdOrName)
//   properties: {
//     roleDefinitionId: contains(avmtypes.builtInRoleNames, roleAssignment.roleDefinitionIdOrName) ? avmtypes.builtInRoleNames[roleAssignment.roleDefinitionIdOrName] : roleAssignment.roleDefinitionIdOrName
//     principalId: roleAssignment.principalId
//     description: roleAssignment.?description
//     principalType: roleAssignment.?principalType
//     condition: roleAssignment.?condition
//     conditionVersion: !empty(roleAssignment.?condition) ? (roleAssignment.?conditionVersion ?? '2.0') : null // Must only be set if condtion is set
//     delegatedManagedIdentityResourceId: roleAssignment.?delegatedManagedIdentityResourceId
//   }
//   scope: data_disk
// }]

resource defaultTelemetry 'Microsoft.Resources/deployments@2023-07-01' = if (enableTelemetry) {
  name: 'pid-47ed15a6-730a-4827-bcb4-0fd963ffbd82-${uniqueString(deployment().name, location)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
    }
  }
}

output dataDiskId string = data_disk.id
