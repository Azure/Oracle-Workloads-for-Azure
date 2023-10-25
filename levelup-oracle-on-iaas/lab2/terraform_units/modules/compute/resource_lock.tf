resource "azurerm_management_lock" "vm" {
  count      = length(var.vm_locks) > 1 && length(try(var.vm_locks.name, "")) > 1 ? 1 : 0
  name       = var.vm_locks.name
  scope      = data.azurerm_virtual_machine.oracle_vm[0].id
  lock_level = var.vm_locks.type

  depends_on = [azurerm_linux_virtual_machine.oracle_vm]
}
