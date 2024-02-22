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

output "nics_oracledb_primary" {
  value = var.is_data_guard ? azurerm_network_interface.oracle_db[0] : null
}

output "nics_oracledb_secondary" {
  value = var.is_data_guard ? azurerm_network_interface.oracle_db[1] : null
}

output "db_server_ips" {
  value = azurerm_network_interface.oracle_db[*].private_ip_addresses[0]
}

output "db_server_puplic_ip" {
  value = azurerm_public_ip.vm_pip[0].ip_address
}
