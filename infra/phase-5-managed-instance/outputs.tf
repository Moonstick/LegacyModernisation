output "app_url" {
  value       = "https://${module.app_service.default_hostname}"
  description = "URL of the deployed web app."
}

output "app_service_name" {
  value       = local.app_name
  description = "Name of the Web App, for use with 'az webapp deploy'."
}

output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "Name of the resource group created for this phase (spans both the primary and secondary regions)."
}

output "key_vault_name" {
  value       = local.key_vault_name
  description = "Name of the Key Vault created for this phase."
}

output "storage_account_name" {
  value       = local.storage_name
  description = "Name of the storage account created for this phase."
}

output "redis_name" {
  value       = local.redis_name
  description = "Name of the Redis cache created for this phase."
}

output "redis_hostname" {
  value       = module.redis.hostname
  description = "Hostname of the Redis cache instance."
}

output "sql_mi_primary_name" {
  value       = local.sql_mi_primary_name
  description = "Name of the primary SQL Managed Instance (var.location)."
}

output "sql_mi_secondary_name" {
  value       = local.sql_mi_secondary_name
  description = "Name of the secondary (DR) SQL Managed Instance (var.secondary_location)."
}

output "sql_mi_primary_fqdn" {
  value       = module.sql_mi_primary.fqdn
  description = "Fully qualified domain name of the primary SQL Managed Instance."
}

output "sql_mi_secondary_fqdn" {
  value       = module.sql_mi_secondary.fqdn
  description = "Fully qualified domain name of the secondary SQL Managed Instance."
}

output "sql_mi_failover_group_id" {
  value       = module.sql_mi_primary.failover_group_id
  description = "ID of the auto-failover group pairing the primary and secondary Managed Instances."
}
