output "account_name" {
  value       = azurerm_storage_account.this.name
  description = "Name of the created storage account."
}

output "primary_blob_endpoint" {
  value       = azurerm_storage_account.this.primary_blob_endpoint
  description = "Primary blob service endpoint URL for the storage account."
}

output "primary_connection_string" {
  value       = azurerm_storage_account.this.primary_connection_string
  sensitive   = true
  description = "Primary connection string for the storage account."
}

output "container_name" {
  value       = azurerm_storage_container.this.name
  description = "Name of the created blob container."
}
