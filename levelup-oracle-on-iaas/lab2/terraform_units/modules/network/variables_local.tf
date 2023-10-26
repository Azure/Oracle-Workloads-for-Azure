locals {
  vnet_oracle_name       = "vnet1"
  database_subnet_name   = "subnet1"
  vnet_oracle_addr       = "10.0.0.0/16"
  database_subnet_prefix = "10.0.0.0/24"

  vnet_oracle_arm_id   = try(local.vnet_oracle_name.arm_id, "")
  vnet_oracle_exists   = length(local.vnet_oracle_arm_id) > 0
  subnet_oracle_arm_id = try(local.database_subnet_name.arm_id, "")
  subnet_oracle_exists = length(local.subnet_oracle_arm_id) > 0

  database_ips = (var.use_secondary_ips) ? (
    flatten(concat(local.database_primary_ips, local.database_secondary_ips))) : (
    local.database_primary_ips
  )

  // Subnet IP Offsets
  // Note: First 4 IP addresses in a subnet are reserved by Azure
  oracle_ip_offsets = {
    oracle_vm = 5 + 1
  }

  database_primary_ips = [
    {
      name                          = "IPConfig1"
      subnet_id                     = data.azurerm_subnet.subnet_oracle[0].id
      nic_ips                       = var.database_nic_ips
      private_ip_address_allocation = var.database.use_DHCP ? "Dynamic" : "Static"
      offset                        = 0
      primary                       = true
    }
  ]

  database_secondary_ips = [
    {
      name                          = "IPConfig2"
      subnet_id                     = data.azurerm_subnet.subnet_oracle[0].id
      nic_ips                       = var.database_nic_secondary_ips
      private_ip_address_allocation = var.database.use_DHCP ? "Dynamic" : "Static"
      offset                        = var.database_server_count
      primary                       = false
    }
  ]

  tags = {}
}
