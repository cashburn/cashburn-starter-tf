resource "azurerm_resource_group" "resource_group" {
  name     = local.base_name
  location = var.location
}

## Add your Terraform resources here ##
