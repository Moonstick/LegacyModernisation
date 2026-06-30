output "hostname" {
  value       = azurerm_redis_cache.this.hostname
  description = "Hostname of the Redis cache instance."
}

output "ssl_port" {
  value       = azurerm_redis_cache.this.ssl_port
  description = "SSL port of the Redis cache instance."
}

output "primary_access_key" {
  value       = azurerm_redis_cache.this.primary_access_key
  sensitive   = true
  description = "Primary access key for the Redis cache instance."
}

output "connection_string" {
  value       = "${azurerm_redis_cache.this.hostname}:${azurerm_redis_cache.this.ssl_port},password=${azurerm_redis_cache.this.primary_access_key},ssl=True,abortConnect=False"
  sensitive   = true
  description = "StackExchange.Redis-compatible connection string for the Redis cache instance."
}
