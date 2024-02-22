#########################################################################################
#                                                                                       #
#  JIT Access Policy                                                                    #
#                                                                                       #
#########################################################################################
data "azurerm_virtual_machine" "oracle_primary_vm" {
  name                = module.vm_primary.vm[0].name
  resource_group_name = module.common_infrastructure.resource_group.name

  depends_on = [module.vm_primary
  ]
}

data "azurerm_virtual_machine" "oracle_secondary_vm" {
  name                = module.vm_secondary.vm[0].name
  resource_group_name = module.common_infrastructure.resource_group.name

  depends_on = [module.vm_secondary
  ]
}


resource "azapi_resource" "jit_ssh_policy_primary" {
  count                     = module.vm_primary.database_server_count
  name                      = "JIT-SSH-Policy-primary"
  parent_id                 = "${module.common_infrastructure.resource_group.id}/providers/Microsoft.Security/locations/${module.common_infrastructure.resource_group.location}"
  type                      = "Microsoft.Security/locations/jitNetworkAccessPolicies@2020-01-01"
  schema_validation_enabled = false
  body = jsonencode({
    "kind" : "Basic"
    "properties" : {
      "virtualMachines" : [{
        "id" : "/subscriptions/${module.common_infrastructure.current_subscription.subscription_id}/resourceGroups/${module.common_infrastructure.resource_group.name}/providers/Microsoft.Compute/virtualMachines/${module.vm_primary.vm[0].name}",
        "ports" : [
          {
            "number" : 22,
            "protocol" : "TCP",
            "allowedSourceAddressPrefix" : "*",
            "maxRequestAccessDuration" : "PT3H"
          }
        ]
      }]
    }
  })

    depends_on = [data.azurerm_virtual_machine.oracle_primary_vm
    , module.storage_primary.data_disks_resource
    , module.storage_primary.asm_disks_resource
    , module.storage_primary.redo_disks_resource
  ]
}

resource "azapi_resource" "jit_ssh_policy_secondary" {
  count                     = module.vm_secondary.database_server_count
  name                      = "JIT-SSH-Policy-secondary"
  parent_id                 = "${module.common_infrastructure.resource_group.id}/providers/Microsoft.Security/locations/${module.common_infrastructure.resource_group.location}"
  type                      = "Microsoft.Security/locations/jitNetworkAccessPolicies@2020-01-01"
  schema_validation_enabled = false
  body = jsonencode({
    "kind" : "Basic"
    "properties" : {
      "virtualMachines" : [{
        "id" : "/subscriptions/${module.common_infrastructure.current_subscription.subscription_id}/resourceGroups/${module.common_infrastructure.resource_group.name}/providers/Microsoft.Compute/virtualMachines/${module.vm_secondary.vm[0].name}",
        "ports" : [
          {
            "number" : 22,
            "protocol" : "TCP",
            "allowedSourceAddressPrefix" : "*",
            "maxRequestAccessDuration" : "PT3H"
          }
        ]
      }]
    }
  })

      depends_on = [data.azurerm_virtual_machine.oracle_secondary_vm
    , module.storage_secondary.data_disks_resource
    , module.storage_secondary.asm_disks_resource
    , module.storage_secondary.redo_disks_resource
  ]
}
