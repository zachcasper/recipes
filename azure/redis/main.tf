terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0, < 4.0"
    }
  }
}

module "naming" {
  source  = "Azure/naming/azurerm"
  prefix = [ "todolist" ]
}

variable "context" {
  description = "Context variable set by Radius which includes the Radius Application, Environment, and other Radius properties"
  type = any
}

variable "resource_group_name" {
  description = "Azure Resource group set via a parameter on the Radius Recipe"
  type = string
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

resource "azurerm_redis_cache" "redis" {
  name                          = module.naming.redis_cache.name_unique
  location                      = var.location
  resource_group_name           = var.resource_group_name
  capacity                      = 0
  family                        = "C"
  sku_name                      = "Basic"
  enable_non_ssl_port           = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
}

resource "azurerm_private_endpoint" "endpoint" {
  name                = module.naming.private_endpoint.name_unique
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = module.naming.private_service_connection.name_unique
    private_connection_resource_id = azurerm_redis_cache.redis.id
    is_manual_connection           = false
    subresource_names              = ["redisCache"]
  }

  private_dns_zone_group {
    name                 = module.naming.private_dns_zone_group.name_unique
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_zone.id]
  }

}

resource "azurerm_private_dns_zone" "dns_zone" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_zone_link" {
  name                  = "todolist-dns-zone-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone.name
  virtual_network_id    = var.vnet_id
}

output "result" {
  value = {
    values = {
      host = azurerm_redis_cache.redis.hostname
      port = azurerm_redis_cache.redis.ssl_port
      username = ""
      tls      = true
    }
    secrets = {
      password = azurerm_redis_cache.redis.primary_access_key
    }
  }
  sensitive = true
}
