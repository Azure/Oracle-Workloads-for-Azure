resource "azurerm_availability_set" "oracle_vm" {
  count               = var.availability_zone == null ? 1 : 0
  name                = "as-${count.index}"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
}

data "azurerm_availability_set" "oracle_vm" {
  count               = var.availability_zone == null ? 1 : 0
  name                = "as-${count.index}"
  resource_group_name = var.resource_group.name

  depends_on = [azurerm_availability_set.oracle_vm]
}
