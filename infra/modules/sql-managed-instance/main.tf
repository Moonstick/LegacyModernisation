# NOTE: SQL Managed Instance provisioning takes 4-6 hours in real Azure.
# This module is fine as a code-only scaffold for the modernization example;
# do not expect `terraform apply` to complete quickly against a real subscription.

resource "azurerm_mssql_managed_instance" "this" {
  name                         = var.name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  subnet_id                    = var.subnet_id
  administrator_login          = var.admin_login
  administrator_login_password = var.admin_password
  license_type                 = "LicenseIncluded"
  sku_name                     = var.sku_name
  vcores                       = var.vcores
  storage_size_in_gb           = var.storage_size_gb
  tags                         = var.tags
}

resource "azurerm_mssql_managed_instance_failover_group" "this" {
  count = var.enable_failover_group ? 1 : 0

  name                         = "${var.name}-fog"
  location                     = var.location
  managed_instance_id          = azurerm_mssql_managed_instance.this.id
  partner_managed_instance_id  = var.partner_managed_instance_id

  read_write_endpoint_failover_policy {
    mode = "Automatic"
  }

  readonly_endpoint_failover_policy_enabled = true
}
