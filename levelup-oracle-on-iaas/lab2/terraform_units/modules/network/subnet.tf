#########################################################################################
#                                                                                       #
#  Subnet                                                                               #
#                                                                                       #
#########################################################################################
resource "azurerm_subnet" "subnet_oracle" {
  count                = local.subnet_oracle_exists ? 0 : 1
  name                 = local.database_subnet_name
  resource_group_name  = var.resource_group.name
  virtual_network_name = data.azurerm_virtual_network.vnet_oracle[count.index].name
  address_prefixes     = [local.database_subnet_prefix]
}

data "azurerm_subnet" "subnet_oracle" {
  count                = local.subnet_oracle_exists ? 0 : 1
  name                 = local.database_subnet_name
  resource_group_name  = var.resource_group.name
  virtual_network_name = data.azurerm_virtual_network.vnet_oracle[count.index].name

  depends_on = [azurerm_subnet.subnet_oracle]
}
