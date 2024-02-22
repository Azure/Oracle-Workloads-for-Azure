#########################################################################################
#                                                                                       #
#  Virtual Network                                                                      #
#                                                                                       #
#########################################################################################
resource "azurerm_virtual_network" "vnet_oracle" {
  count               = local.vnet_oracle_exists ? 0 : 1
  name                = local.vnet_oracle_name
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  address_space       = [local.vnet_oracle_addr]

  tags = merge(local.tags, var.tags)
}

data "azurerm_virtual_network" "vnet_oracle" {
  count               = local.vnet_oracle_exists ? 0 : 1
  name                = local.vnet_oracle_name
  resource_group_name = var.resource_group.name

  depends_on = [azurerm_virtual_network.vnet_oracle]
}
