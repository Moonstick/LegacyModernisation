output "vm_public_ip" {
  value       = module.vm.public_ip_address
  description = "Public IP address of the Phase 0 VM. The app is reachable at http://<this>/ once cloud-init finishes."
}

output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "Name of the resource group created for this phase, for use with teardown.sh or manual inspection."
}
