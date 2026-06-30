output "vault_uri" {
  value       = azurerm_key_vault.this.vault_uri
  description = "URI of the created Key Vault."
}

output "key_vault_id" {
  value       = azurerm_key_vault.this.id
  description = "ID of the created Key Vault."
}
