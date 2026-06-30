output "server_fqdn" {
  value       = azurerm_mssql_server.this.fully_qualified_domain_name
  description = "Fully qualified domain name of the SQL logical server."
}

output "database_id" {
  value       = azurerm_mssql_database.this.id
  description = "ID of the created SQL database."
}

output "connection_string" {
  value       = "Server=tcp:${azurerm_mssql_server.this.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.this.name};Persist Security Info=False;User ID=${var.admin_login};Password=${var.admin_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  sensitive   = true
  description = "ADO.NET connection string for the SQL database, including administrator credentials."
}
