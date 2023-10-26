locals {
  resource_group_exists = length(try(var.infrastructure.resource_group.arm_id, "")) > 0
  // If resource ID is specified extract the resourcegroup name from it otherwise read it either from input of create using the naming convention
  rg_name = local.resource_group_exists ? (
    try(split("/", var.infrastructure.resource_group.arm_id))[4]) : (
    length(var.infrastructure.resource_group.name) > 0 ? (
      var.infrastructure.resource_group.name) : (
      format("%s-%s-%s-%s-%s",
        "rg",
        local.prefix,
        "demo",
        var.infrastructure.region,
        "001"
      )
    )
  )

  // Resource group
  prefix = "oracle"

  tags = {}
}
