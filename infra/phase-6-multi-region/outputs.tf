output "front_door_hostname" {
  value       = "https://${module.front_door.endpoint_hostname}"
  description = "Global Front Door entry point -- this is the URL end users (and load tests) should actually use; it load-balances active/active across both regions and stops routing to whichever region fails its health probe."
}

output "primary_app_url" {
  value       = "https://${module.app_service_primary.default_hostname}"
  description = "Direct URL of the primary region's App Service, bypassing Front Door. Useful for diagnosing a single region in isolation, including during a manual failover drill."
}

output "secondary_app_url" {
  value       = "https://${module.app_service_secondary.default_hostname}"
  description = "Direct URL of the secondary region's App Service, bypassing Front Door. Useful for diagnosing a single region in isolation, including during a manual failover drill."
}

output "primary_app_service_name" {
  value       = "${local.primary_prefix}-app"
  description = "Name of the primary region's Web App, for use with 'az webapp deploy'."
}

output "secondary_app_service_name" {
  value       = "${local.secondary_prefix}-app"
  description = "Name of the secondary region's Web App, for use with 'az webapp deploy'."
}

output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "Name of the single resource group created for this phase, containing both regions' resources."
}
