locals {
  location = "North Europe"
  container_registry_rg_name = "caso-practico-2-acr-rg"
  acr_name = "casopractico2acr"
}

resource "azurerm_resource_group" "container_registry_rg" {
  name     = local.container_registry_rg_name
  location = local.location
}

resource "azurerm_container_registry" "acr" {
  name                     = local.acr_name
  resource_group_name      = azurerm_resource_group.container_registry_rg.name
  location                 = azurerm_resource_group.container_registry_rg.location
  sku                      = var.acr_sku
  admin_enabled            = true
}