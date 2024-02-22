// ================ //
// The following type definitions are created for easier and consistent creation of 
// parameter files for the Bicep templates.
// ================ //

@export()
@description('Type for description of virtual network')
type vnetType = {
  @description('Name of the virtual network')
  virtualNetworkName: string

  @description('Address prefix for the virtual network')
  addressPrefixes: string[]

  @description('Type for description of diagnostic settings')
  diagnosticSettings: diagnosticSettingType?

  @description('Type for description of role assignments')
  roleAssignments: roleAssignmentType?

  @description('Type for description of lock')
  lock: lockType?
}

@export()
@description('Type for description of subnet')
type subnetType = {
  @description('Name of the subnet')
  subnetName: string

  @description('Address prefix for the subnet')
  addressPrefix: string

  @description('Virtual network name')
  virtualNetworkName: string

  @description('Network security group name')
  networkSecurityGroupName: string?
}

@export()
@description('Type for description of Public IP Address')
type pipType = {

  @description('Name of the Public IP Address')
  publicIPAddressName: string

  @description('Diagnostic settings')
  diagnosticSettings: diagnosticSettingType?

  @description('Role assignments')
  roleAssignments: roleAssignmentType?

  @description('Lock')
  lock: lockType?
}

@export()
@description('Type for description of Network Security Group')
type nsgType = {
  @description('Name of the Network Security Group')
  networkSecurityGroupName: string

  @description('Security Rules')
  securityRules: securityRuleType[]?

  @description('Diagnostic settings')
  diagnosticSettings: diagnosticSettingType?

  @description('Role assignments')
  roleAssignments: roleAssignmentType?

  @description('Lock')
  lock: lockType?
}

@export()
@description('Type for description of Network Interface')
type nicType = {

  @description('Name of the Network Interface')
  networkInterfaceName: string

  @description('Virtual network name')
  virtualNetworkName: string

  @description('Subnet name')
  subnetName: string

  @description('Public IP Address name')
  publicIPAddressName: string

  @description('Diagnostic settings')
  diagnosticSettings: diagnosticSettingType?

  @description('Role assignments')
  roleAssignments: roleAssignmentType?

  @description('Lock')
  lock: lockType?
}

@export()
@description('Type for description of Data Disk')
type dataDiskType = {
  @description('Name of the Data Disk')
  diskName: string

  @description('Size of the Data Disk')
  diskSizeGB: int

  @description('Type of the Data Disk')
  type: string

  @description('LUN of the Data Disk')
  lun: int

  @description('Host disk caching on the Data Disk')
  hostDiskCaching: string

  @description('Virtual Machine Name to which data disk needs to be attached')
  virtualMachineName: string

  @description('Availability Zone where disk needs to be created')
  avZone: int

  @description('Diagnostic settings')
  diagnosticSettings: diagnosticSettingType?

  @description('Role assignments')
  roleAssignments: roleAssignmentType?

  @description('Lock')
  lock: lockType?
}

@export()
@description('Type for description of Virtual Machine')
type vmType = {
  @description('Name of the Virtual Machine')
  virtualMachineName: string

  @description('SKU of the Virtual machine')
  vmSize: string

  @description('Admin user name')
  adminUsername: string

  @description('SSH Public Key')
  sshPublicKey: string

  @description('Availability Zone where VM needs to be created')
  avZone: int

  @description('Diagnostic settings')
  diagnosticSettings: diagnosticSettingType?

  @description('Role assignments')
  roleAssignments: roleAssignmentType?

  @description('Lock')
  lock: lockType?
}

@export()
@description('This type is used for describing Security rules in a network security group')
type securityRuleType = {

  @description('Required. The name of the security rule.')
  securityRuleName: string

  @description('Required. The description of the security rule.')
  securityRuleDescription: string

  @description('Required. Allow or Deny')
  access: string

  @description('Required. The priority of the rule.')
  priority: int

  @description('Required. The direction of the rule. Inbound or Outbound')
  direction: string

  @description('Required. The protocol of the rule. TCP, UDP, ICMP, or * to match all protocols.')
  protocol: string

  @description('Required. The source port or range. Integer or range between 0 and 65535. Asterisk (*) to match all ports.')
  sourcePortRange: string

  @description('Required. The destination port or range. Integer or range between 0 and 65535. Asterisk (*) to match all ports.')
  destinationPortRange: string

  @description('Required. The source address prefix. CIDR or source IP range. Asterisk (*) to match all source IPs.')
  sourceAddressPrefix: string

  @description('Required. The destination address prefix. CIDR or destination IP range. Asterisk (*) to match all destination IPs.')
  destinationAddressPrefix: string
}

@export()
type diagnosticSettingType = {

  @description('Optional. The name of diagnostic setting.')
  name: string?

  @description('Optional. The name of logs that will be streamed. "allLogs" includes all possible logs for the resource. Set to \'\' to disable log collection.')
  logCategoriesAndGroups: {

    @description('Optional. Name of a Diagnostic Log category for a resource type this setting is applied to. Set the specific logs to collect here.')
    category: string?

    @description('Optional. Name of a Diagnostic Log category group for a resource type this setting is applied to. Set to `allLogs` to collect all logs.')
    categoryGroup: string?

    @description('Required. Enabled or Disabled flag for a Diagnostic Metric category for a resource type this setting is applied to.')
    enabled: bool
  }[]?

  @description('Optional. The name of logs that will be streamed. "allLogs" includes all possible logs for the resource. Set to \'\' to disable log collection.')
  metricCategories: {

    @description('Required. Name of a Diagnostic Metric category for a resource type this setting is applied to. Set to `AllMetrics` to collect all metrics.')
    category: string

    @description('Required. Enabled or Disabled flag for a Diagnostic Metric category for a resource type this setting is applied to.')
    enabled: bool
  }[]?

  @description('Optional. VM agent configuration')
  vmAgentConfiguration: {

    @description('VM extension publisher')
    publisher: string?

    @description('VM extension type')
    type: string?

    @description('Type handler version')
    typeHandlerVersion: string?

    @description('Auto upgrade minor version')
    autoUpgradeMinorVersion: bool?

    @description('Enable automatic upgrade')
    enableAutomaticUpgrade: bool?

  }?

  @description('Optional. Enable VM guest monitoring')
  enableVmGuestMonitoring: bool?

  @description('Optional. A string indicating whether the export to Log Analytics should use the default destination type, i.e. AzureDiagnostics, or use a destination type.')
  logAnalyticsDestinationType: ('Dedicated' | 'AzureDiagnostics')?

  @description('Optional. Resource ID of the diagnostic log analytics workspace. For security reasons, it is recommended to set diagnostic settings to send data to either storage account, log analytics workspace or event hub.')
  workspaceResourceId: string?

  @description('Optional. Resource ID of the diagnostic storage account. For security reasons, it is recommended to set diagnostic settings to send data to either storage account, log analytics workspace or event hub.')
  storageAccountResourceId: string?

  @description('Optional. Resource ID of the diagnostic event hub authorization rule for the Event Hubs namespace in which the event hub should be created or streamed to.')
  eventHubAuthorizationRuleResourceId: string?

  @description('Optional. Name of the diagnostic event hub within the namespace to which logs are streamed. Without this, an event hub is created for each log category. For security reasons, it is recommended to set diagnostic settings to send data to either storage account, log analytics workspace or event hub.')
  eventHubName: string?

  @description('Optional. The full ARM resource ID of the Marketplace resource to which you would like to send Diagnostic Logs.')
  marketplacePartnerResourceId: string?
}[]?

@export()
type roleAssignmentType = {

  @description('Required. The name of the role to assign. If it cannot be found you can specify the role definition ID instead.')
  roleDefinitionIdOrName: string

  @description('Required. The principal ID of the principal (user/group/identity) to assign the role to.')
  principalId: string

  @description('Optional. The principal type of the assigned principal ID.')
  principalType: ('ServicePrincipal' | 'Group' | 'User' | 'ForeignGroup' | 'Device')?

  @description('Optional. The description of the role assignment.')
  description: string?

  @description('Optional. The conditions on the role assignment. This limits the resources it can be assigned to. e.g.: @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:ContainerName] StringEqualsIgnoreCase "foo_storage_container"')
  condition: string?

  @description('Optional. Version of the condition.')
  conditionVersion: '2.0'?

  @description('Optional. The Resource Id of the delegated managed identity resource.')
  delegatedManagedIdentityResourceId: string?
}[]?

@export()
type lockType = {

  @description('Optional. Specify the name of lock.')
  name: string?

  @description('Optional. Specify the type of lock.')
  kind: ('CanNotDelete' | 'ReadOnly' | 'None')?
}?

@export()
var builtInRoleNames = {
  Contributor: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  'DNS Resolver Contributor': subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0f2ebee7-ffd4-4fc0-b3b7-664099fdad5d')
  'DNS Zone Contributor': subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'befefa01-2a29-4197-83a8-272ff33ce314')
  'Network Contributor': subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')
  Owner: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
  'Private DNS Zone Contributor': subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b12aa53e-6015-4669-85d0-8515ebb3ae7f')
  Reader: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
  'Role Based Access Control Administrator (Preview)': subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'f58310d9-a9f6-439a-9e8d-f62e7b41a168')
}

@export()
var vnetResourcePrefix = 'vnet'
@export()
var subnetResourcePrefix = 'snet'
@export()
var pipResourcePrefix = 'pip'
@export() 
var nsgResourcePrefix = 'nsg'
@export()
var nicResourcePrefix = 'nic'
@export()
var dataDiskResourcePrefix = 'disk'
@export()
var vmResourcePrefix = 'vm'
@export()
var resourceGroupPrefix = 'rg'
