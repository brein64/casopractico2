terraform {
  required_version = "~> 1.5"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
       version = "3.95.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  tenant_id       = "899789dc-202f-44b4-8472-a6d40f9eb440"
  subscription_id = "f36cc325-eaf2-4a52-a760-bcbe47ba94fe" # Azure for Students
}
