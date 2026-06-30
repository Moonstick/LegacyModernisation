output "endpoint_hostname" {
  value       = azurerm_cdn_frontdoor_endpoint.this.host_name
  description = "Hostname of the Front Door endpoint."
}

output "frontdoor_id" {
  value       = azurerm_cdn_frontdoor_profile.this.id
  description = "ID of the Front Door profile."
}
