#########################################################################################
#                                                                                       #
#  Role Assignments                                                                     #
#                                                                                       #
#########################################################################################
// User defined identity for all Deployers, assign contributor to the current subscription
resource "azurerm_user_assigned_identity" "deployer" {
  count               = 1
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  name                = "deployer"
}

resource "azurerm_role_assignment" "sub_contributor" {
  count                            = var.assign_subscription_permissions && var.aad_system_assigned_identity ? 1 : 0
  scope                            = "/subscriptions/${var.subscription_id}"
  role_definition_name             = "Contributor"
  principal_id                     = azurerm_linux_virtual_machine.oracle_vm[count.index].identity[0].principal_id
  skip_service_principal_aad_check = var.skip_service_principal_aad_check
}
