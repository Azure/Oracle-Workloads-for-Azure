###############################################################################
#                                                                             #
#                            Network                                          #
#                                                                             #
###############################################################################
output "network_location" {
  value = data.azurerm_virtual_network.vnet_oracle[0].location
}

output "db_subnet" {
  value = data.azurerm_subnet.subnet_oracle[0]
}

output "nics_oracledb" {
  value = azurerm_network_interface.oracle_db
}

output "db_server_ips" {
  value = azurerm_network_interface.oracle_db[*].private_ip_addresses[0]
}
