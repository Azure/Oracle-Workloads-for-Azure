module "common_infrastructure" {
  source = "../../../terraform_units/modules/common_infrastructure"

  infrastructure                 = local.infrastructure
  is_diagnostic_settings_enabled = var.is_diagnostic_settings_enabled
  diagnostic_target              = var.diagnostic_target
  availability_zone              = 1
  tags                           = var.resourcegroup_tags
}

module "vm" {
  source = "../../../terraform_units/modules/compute"

  subscription_id           = module.common_infrastructure.current_subscription.subscription_id
  resource_group            = module.common_infrastructure.resource_group
  vm_name                   = "vm"
  public_key                = var.ssh_key
  sid_username              = "oracle"
  nic_id                    = module.network.nics_oracledb[0].id
  vm_sku                    = var.vm_sku
  vm_source_image_reference = var.vm_source_image_reference

  vm_os_disk = var.vm_os_disk

  aad_system_assigned_identity    = false
  assign_subscription_permissions = true

  is_diagnostic_settings_enabled = module.common_infrastructure.is_diagnostic_settings_enabled
  diagnostic_target              = module.common_infrastructure.diagnostic_target
  storage_account_id             = module.common_infrastructure.target_storage_account_id
  storage_account_sas_token      = module.common_infrastructure.target_storage_account_sas
  log_analytics_workspace_id     = module.common_infrastructure.log_analytics_workspace_id
  eventhub_authorization_rule_id = module.common_infrastructure.eventhub_authorization_rule_id
  partner_solution_id            = module.common_infrastructure.partner_solution_id
  tags                           = module.common_infrastructure.tags

  availability_zone = module.common_infrastructure.availability_zone

  role_assignments = {
    role_assignment_1 = {
      name                             = "Virtual Machine Contributor"
      skip_service_principal_aad_check = false
    }
  }
}

module "network" {
  source = "../../../terraform_units/modules/network"

  resource_group                 = module.common_infrastructure.resource_group
  is_data_guard                  = module.common_infrastructure.is_data_guard
  is_diagnostic_settings_enabled = module.common_infrastructure.is_diagnostic_settings_enabled
  diagnostic_target              = module.common_infrastructure.diagnostic_target
  storage_account_id             = module.common_infrastructure.target_storage_account_id
  log_analytics_workspace_id     = module.common_infrastructure.log_analytics_workspace_id
  eventhub_authorization_rule_id = module.common_infrastructure.eventhub_authorization_rule_id
  partner_solution_id            = module.common_infrastructure.partner_solution_id
  tags                           = module.common_infrastructure.tags

  role_assignments_nic = {
    role_assignment_1 = {
      name                             = "Contributor"
      skip_service_principal_aad_check = false
    }
  }

  role_assignments_pip = {
    role_assignment_1 = {
      name                             = "Contributor"
      skip_service_principal_aad_check = false
    }
  }

  role_assignments_nsg = {
    role_assignment_1 = {
      name                             = "Contributor"
      skip_service_principal_aad_check = false
    }
  }

  role_assignments_vnet = {
    role_assignment_1 = {
      name                             = "Contributor"
      skip_service_principal_aad_check = false
    }
  }

  role_assignments_subnet = {
    role_assignment_1 = {
      name                             = "Contributor"
      skip_service_principal_aad_check = false
    }
  }
}

module "storage" {
  source = "../../../terraform_units/modules/storage"

  resource_group = module.common_infrastructure.resource_group
  naming         = "oracle"
  vm             = module.vm.vm[0]
  tags           = module.common_infrastructure.tags
  database_disks_options = {
    data_disks = var.database_disks_options.data_disks
    asm_disks  = var.database_disks_options.asm_disks
    redo_disks = var.database_disks_options.redo_disks
  }
  availability_zone = module.common_infrastructure.availability_zone

  role_assignments = {
    role_assignment_1 = {
      name                             = "Contributor"
      skip_service_principal_aad_check = false
    }
  }
}

