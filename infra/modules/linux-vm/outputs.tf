output "vm_id" {
  value       = azurerm_linux_virtual_machine.this.id
  description = "ID of the created virtual machine."
}

output "private_ip_address" {
  value       = azurerm_network_interface.this.private_ip_address
  description = "Private IP address assigned to the virtual machine's network interface."
}

output "public_ip_address" {
  value       = var.assign_public_ip ? azurerm_public_ip.this[0].ip_address : ""
  description = "Public IP address assigned to the virtual machine, or an empty string if none was assigned."
}

output "network_interface_id" {
  value       = azurerm_network_interface.this.id
  description = "ID of the virtual machine's network interface."
}
