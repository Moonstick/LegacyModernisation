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
  description = "Name of the resource group created for this phase."
}

output "key_vault_name" {
  value       = local.key_vault_name
  description = "Name of the Key Vault created for this phase."
}

output "storage_account_name" {
  value       = module.storage.account_name
  description = "Name of the Storage Account created for this phase, holding claim attachments."
}
