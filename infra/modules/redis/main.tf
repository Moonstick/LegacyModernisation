resource "azurerm_redis_cache" "this" {
  name                 = var.name
  location             = var.location
  resource_group_name  = var.resource_group_name
  sku_name             = var.sku_name
  family               = var.family
  capacity             = var.capacity
  non_ssl_port_enabled = var.enable_non_ssl_port
  tags                 = var.tags
}
