#########################################################################################
#                                                                                       #
#  NIC                                                                                  #
#                                                                                       #
#########################################################################################
resource "azurerm_network_interface" "oracle_db" {
  count = 1
  name  = "oraclevmnic1"

  location                      = var.resource_group.location
  resource_group_name           = var.resource_group.name
  enable_accelerated_networking = true

  dynamic "ip_configuration" {
    iterator = pub
    for_each = local.database_ips
    content {
      name      = pub.value.name
      subnet_id = pub.value.subnet_id
      private_ip_address = try(pub.value.nic_ips[count.index],
        var.database.use_DHCP ? (
          null) : (
          cidrhost(
            data.azurerm_subnet.subnet_oracle[0].address_prefixes[0],
            tonumber(count.index) + local.oracle_ip_offsets.oracle_db_vm + pub.value.offset
          )
        )
      )
      private_ip_address_allocation = length(try(pub.value.nic_ips[count.index], "")) > 0 ? (
        "Static") : (
        pub.value.private_ip_address_allocation
      )

      public_ip_address_id = azurerm_public_ip.vm_pip.id

      primary = pub.value.primary
    }
  }

  tags = merge(local.tags, var.tags)
}

data "azurerm_network_interface" "oracle_db" {
  count               = 1
  name                = "oraclevmnic1"
  resource_group_name = var.resource_group.name

  depends_on = [azurerm_network_interface.oracle_db]
}

resource "azurerm_public_ip" "vm_pip" {
  name                = "vmpip"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  allocation_method   = "Dynamic"

  tags = merge(local.tags, var.tags)
}

data "azurerm_public_ip" "vm_pip" {
  name                = "vmpip"
  resource_group_name = var.resource_group.name

  depends_on = [azurerm_public_ip.vm_pip]
}
