output "app_service_id" {
  value       = azurerm_linux_web_app.this.id
  description = "ID of the created Linux Web App."
}

output "default_hostname" {
  value       = azurerm_linux_web_app.this.default_hostname
  description = "Default hostname assigned to the web app."
}

output "principal_id" {
  value       = azurerm_linux_web_app.this.identity[0].principal_id
  description = "Principal ID of the web app's system-assigned managed identity."
}

output "service_plan_id" {
  value       = azurerm_service_plan.this.id
  description = "ID of the App Service Plan hosting the web app."
}
