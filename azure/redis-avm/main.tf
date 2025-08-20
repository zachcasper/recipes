# Source: https://registry.terraform.io/modules/Azure/avm-res-cache-redis/azurerm/latest/examples/default

terraform {
  required_version = "~> 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
  }
}

variable "context" {
  description = "Context variable set by Radius which includes the Radius Application, Environment, and other Radius properties"
  type = any
}

variable "location" {
  description = "Azure region set via a parameter on the Radius Recipe"
  type = string
}

variable "vnet_id" {
  description = "The vnet ID to create a private endpoint"
  type = string
}

variable "subnet_id" {
  description = "The subnet ID to create a private endpoint"
  type = string
}

locals {
  tags = {
    scenario = "default"
  }
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"
  prefix = [ var.context.application.name ]
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "azurerm_resource_group" "this" {
  location = var.location
  name     = module.naming.resource_group.name_unique
}

resource "azurerm_private_dns_zone" "this" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "vnet-link"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id    = var.vnet_id
}

resource "azurerm_log_analytics_workspace" "this_workspace" {
  location            = var.location
  name                = module.naming.log_analytics_workspace.name_unique
  resource_group_name = azurerm_resource_group.this.name
  retention_in_days   = 30
  sku                 = "PerGB2018"
  tags                = local.tags
}

module "avm-res-cache-redis" {
  source             = "Azure/avm-res-cache-redis/azurerm"
  version            = "0.4.0"

  name                          = module.naming.redis_cache.name_unique
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  public_network_access_enabled = false
  private_endpoints = {
    endpoint1 = {
      subnet_resource_id            = var.subnet_id
      private_dns_zone_group_name   = "private-dns-zone-group"
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.this.id]
    }
  }

  diagnostic_settings = {
    diag_setting_1 = {
      name                           = "diagSetting1"
      log_groups                     = ["allLogs"]
      metric_categories              = ["AllMetrics"]
      log_analytics_destination_type = null
      workspace_resource_id          = azurerm_log_analytics_workspace.this_workspace.id
    }
  }

  redis_configuration = {
    maxmemory_reserved = 1330
    maxmemory_delta    = 1330
    maxmemory_policy   = "allkeys-lru"
  }
  /*
  lock = {
    kind = "CanNotDelete"
    name = "Delete"
  }
  */

  managed_identities = {
    system_assigned = true
  }

  tags = local.tags
}

output "result" {
  value = {
    values = {
      host = module.avm-res-cache-redis.resource.hostname
      port = module.avm-res-cache-redis.resource.ssl_port
      username = ""
      tls      = true
    }
    secrets = {
      password = module.avm-res-cache-redis.resource.primary_access_key
    }
  }
  sensitive = true
}
