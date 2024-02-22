locals {
  sid_auth_type        = try(var.database.authentication.type, "key")
  enable_auth_password = local.sid_auth_type == "password"
  enable_auth_key      = local.sid_auth_type == "key"

  enable_ultradisk = false
  tags = {}
}
