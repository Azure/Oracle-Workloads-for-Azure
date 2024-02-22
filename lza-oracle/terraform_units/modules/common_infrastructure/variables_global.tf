variable "infrastructure" {}

variable "is_data_guard" {
  description = "Whether Data Guard is enabled"
  default     = false
}

variable "is_diagnostic_settings_enabled" {
  description = "Whether diagnostic settings are enabled"
  default     = false
}

variable "diagnostic_target" {
  description = "The destination type of the diagnostic settings"
  default     = "Log_Analytics_Workspace"
  validation {
    condition     = contains(["Log_Analytics_Workspace", "Storage_Account", "Event_Hubs", "Partner_Solutions"], var.diagnostic_target)
    error_message = "Allowed values are Log_Analytics_Workspace, Storage_Account, Event_Hubs, Partner_Solutions"
  }
}

variable "eventhub_permission" {
  description = "Authorization rule permissions for Event Hub"
  default = {
    listen = true
    send   = true
    manage = true
  }
}

variable "logz_user" {
  description = "Logz.io"
  default = {
    email        = "user@example.com"
    first_name   = "Example"
    last_name    = "User"
    phone_number = "+12313803556"
  }
}

variable "role_assignments" {
  description = "Role assignments"
  default     = {}
}

variable "subscription_locks" {
  type = object({
    name = optional(string, "")
    type = optional(string, "CanNotDelete")
  })
  default = {}
  validation {
    condition     = contains(["CanNotDelete", "ReadOnly"], var.subscription_locks.type)
    error_message = "Lock type must be one of: CanNotDelete, ReadOnly."
  }
}

variable "resource_group_locks" {
  type = object({
    name = optional(string, "")
    type = optional(string, "CanNotDelete")
  })
  default = {}
  validation {
    condition     = contains(["CanNotDelete", "ReadOnly"], var.resource_group_locks.type)
    error_message = "Lock type must be one of: CanNotDelete, ReadOnly."
  }
}

variable "availability_zone" {
  description = "The availability zones of the resource"
  default     = null
}

variable "tags" {
  description = "Tags to be added to the resources"
  default     = {}
}
