output "vm" {
  value = azurerm_linux_virtual_machine.oracle_vm
}

output "database_server_count" {
  value = var.database_server_count
}

output "availability_zone" {
  value = var.availability_zone != null ? var.availability_zone : null
}
