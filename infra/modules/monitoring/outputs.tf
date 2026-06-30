output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.this.id
  description = "ID of the Log Analytics workspace."
}

output "app_insights_connection_string" {
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
  description = "Connection string for the Application Insights instance."
}

output "app_insights_instrumentation_key" {
  value       = azurerm_application_insights.this.instrumentation_key
  sensitive   = true
  description = "Instrumentation key for the Application Insights instance."
}
