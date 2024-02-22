resource "azurerm_management_lock" "subscription" {
  count      = length(var.subscription_locks) > 1 && length(try(var.subscription_locks.name, "")) > 0 ? 1 : 0
  name       = var.subscription_locks.name
  scope      = data.azurerm_subscription.current.id
  lock_level = var.subscription_locks.type
}

resource "azurerm_management_lock" "resource_group" {
  count      = length(var.resource_group_locks) > 1 && length(try(var.resource_group_locks.name, "")) > 0 ? 1 : 0
  name       = var.resource_group_locks.name
  scope      = data.azurerm_resource_group.rg.id
  lock_level = var.resource_group_locks.type

  depends_on = [azurerm_resource_group.rg]
}
