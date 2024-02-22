#########################################################################################
#                                                                                       #
#  JIT Access Policy                                                                    #
#                                                                                       #
#########################################################################################
data "azurerm_virtual_machine" "oracle_vm" {
  name                = module.vm.vm[0].name
  resource_group_name = module.common_infrastructure.resource_group.name

  depends_on = [module.vm
  ]
}

# resource "time_sleep" "wait" {
#   create_duration = "200s"

#   depends_on = [
#     module.storage.data_disks_resource,
#     module.storage.asm_disks_resource,
#     module.storage.redo_disks_resource
#   ]
# }

resource "azapi_resource" "jit_ssh_policy" {
  count                     = module.vm.database_server_count
  name                      = "JIT-SSH-Policy"
  parent_id                 = "${module.common_infrastructure.resource_group.id}/providers/Microsoft.Security/locations/${module.common_infrastructure.resource_group.location}"
  type                      = "Microsoft.Security/locations/jitNetworkAccessPolicies@2020-01-01"
  schema_validation_enabled = false
  body = jsonencode({
    "kind" : "Basic"
    "properties" : {
      "virtualMachines" : [{
        "id" : "/subscriptions/${module.common_infrastructure.current_subscription.subscription_id}/resourceGroups/${module.common_infrastructure.resource_group.name}/providers/Microsoft.Compute/virtualMachines/${data.azurerm_virtual_machine.oracle_vm.name}",
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

  depends_on = [data.azurerm_virtual_machine.oracle_vm
    , module.storage.data_disks_resource
    , module.storage.asm_disks_resource
    , module.storage.redo_disks_resource
  ]
}
