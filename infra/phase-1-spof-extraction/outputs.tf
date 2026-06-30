output "lb_public_ip" {
  value       = module.lb.public_ip_address
  description = "Public IP address of the load balancer fronting the two web VMs. The app is reachable at http://<this>/ once both instances finish cloud-init."
}

output "db_vm_public_ip" {
  value       = module.db_vm.public_ip_address
  description = "Public IP of the dedicated SQL Server VM, for SSH troubleshooting access."
}

output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "Name of the resource group created for this phase, for use with teardown.sh or manual inspection."
}
