locals {
  name_prefix    = "claims-phase2-${var.resource_group_suffix}"
  app_name       = "${local.name_prefix}-app"
  key_vault_name = "kv-claims-p2-${var.resource_group_suffix}"
  tags = merge(var.tags, {
    project = "claims-modernization"
    phase   = "2-paas-foundations"
  })
}

resource "azurerm_resource_group" "this" {
  name     = "rg-claims-phase2-${var.resource_group_suffix}"
  location = var.location
  tags     = local.tags
}

module "monitoring" {
  source = "../modules/monitoring"

  name                = local.name_prefix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  tags = local.tags
}

module "sql" {
  source = "../modules/sql-database"

  name                 = "${local.name_prefix}-sql"
  database_name        = "claimsdb"
  location             = azurerm_resource_group.this.location
  resource_group_name  = azurerm_resource_group.this.name
  admin_login          = var.sql_admin_login
  admin_password       = var.sql_admin_password
  allow_azure_services = true

  tags = local.tags
}

module "app_service" {
  source = "../modules/app-service"

  name                = local.app_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = var.app_service_sku

  # The SQL connection string is read from Key Vault via an App Service Key
  # Vault reference (the "@Microsoft.KeyVault(...)" value below) rather than
  # the app calling the Key Vault SDK directly -- App Service resolves it
  # into a plain environment variable before the app starts, so no code
  # change is needed. The web app's managed identity is granted access to
  # the secret below, via module.key_vault.access_object_ids.
  app_settings = {
    "ConnectionStrings__ClaimsDb"           = "@Microsoft.KeyVault(SecretUri=${module.key_vault.vault_uri}secrets/ClaimsDb-ConnectionString/)"
    "Storage__Provider"                     = "Local"
    "Redis__ConnectionString"               = ""
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = module.monitoring.app_insights_connection_string
  }

  tags = local.tags
}

module "key_vault" {
  source = "../modules/key-vault"

  name                = local.key_vault_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = var.tenant_id

  secrets = {
    "ClaimsDb-ConnectionString" = module.sql.connection_string
  }

  access_object_ids = [module.app_service.principal_id]

  tags = local.tags
}
