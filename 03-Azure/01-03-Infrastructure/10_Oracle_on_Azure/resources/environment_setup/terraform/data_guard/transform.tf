locals {
  infrastructure = {
    region = coalesce(var.location, try(var.infrastructure.region, ""))
    resource_group = {
      name = try(
        coalesce(
          var.resourcegroup_name,
          try(var.infrastructure.resource_group.name, "")
        ),
        ""
      )
    }
    vnet = {
      name = try(
        coalesce(
          local.vnet_oracle_name,
          try(var.infrastructure.vnet.name, "")
        ),
        ""
      )
    }
    subnet = {
      name = try(
        coalesce(
          local.database_subnet_name,
          try(var.infrastructure.subnet.name, "")
        ),
        ""
      )
    }
    tags = try(
      coalesce(
        var.resourcegroup_tags,
        try(var.infrastructure.tags, {})
      ),
      {}
    )
  }
}
