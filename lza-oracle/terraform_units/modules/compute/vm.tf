#########################################################################################
#                                                                                       #
#  Virtual Machine                                                                      #
#                                                                                       #
#########################################################################################
resource "azurerm_linux_virtual_machine" "oracle_vm" {
  count               = 1
  name                = "${var.vm_name}-${count.index}"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  admin_username                  = var.sid_username
  disable_password_authentication = !local.enable_auth_password

  admin_ssh_key {
    username   = var.sid_username
    public_key = var.public_key
  }

  source_image_reference {
    publisher = var.vm_source_image_reference.publisher
    offer     = var.vm_source_image_reference.offer
    sku       = var.vm_source_image_reference.sku
    version   = var.vm_source_image_reference.version
  }
  size = var.vm_sku

  os_disk {
    name                   = var.vm_os_disk.name
    caching                = var.vm_os_disk.caching
    storage_account_type   = var.vm_os_disk.storage_account_type
    disk_encryption_set_id = try(var.vm_os_disk.disk_encryption_set_id, null)
    disk_size_gb           = var.vm_os_disk.disk_size_gb
  }

  network_interface_ids = [var.nic_id]


  additional_capabilities {
    ultra_ssd_enabled = local.enable_ultradisk
  }

  identity {
    type         = var.aad_system_assigned_identity ? "SystemAssigned, UserAssigned" : "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.deployer[0].id]
  }

  zone                = var.availability_zone
  availability_set_id = var.availability_zone == null ? data.azurerm_availability_set.oracle_vm[0].id : null

  tags = merge(local.tags, var.tags)

  lifecycle {
    ignore_changes = [
      // Ignore changes to computername
      tags,
      computer_name
    ]
  }
}

data "azurerm_virtual_machine" "oracle_vm" {
  count               = 1
  name                = "${var.vm_name}-${count.index}"
  resource_group_name = var.resource_group.name

  depends_on = [azurerm_linux_virtual_machine.oracle_vm]
}
