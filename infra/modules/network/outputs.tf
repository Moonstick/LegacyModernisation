output "vnet_id" {
  value       = azurerm_virtual_network.this.id
  description = "ID of the created virtual network."
}

output "subnet_ids" {
  value       = { for k, s in azurerm_subnet.this : k => s.id }
  description = "Map of subnet IDs keyed by the same keys as the subnets input."
}

output "nsg_ids" {
  value       = { for k, n in azurerm_network_security_group.this : k => n.id }
  description = "Map of network security group IDs keyed by the same keys as the subnets input."
}
