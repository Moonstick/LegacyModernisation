output "mi_id" {
  value       = azurerm_mssql_managed_instance.this.id
  description = "ID of the created SQL Managed Instance."
}

output "fqdn" {
  value       = azurerm_mssql_managed_instance.this.fqdn
  description = "Fully qualified domain name of the SQL Managed Instance."
}

output "failover_group_id" {
  value       = var.enable_failover_group ? azurerm_mssql_managed_instance_failover_group.this[0].id : ""
  description = "ID of the failover group, or an empty string if failover was not enabled."
}
