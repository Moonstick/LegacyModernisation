locals {
  name_prefix    = "claims-phase3-${var.resource_group_suffix}"
  app_name       = "${local.name_prefix}-app"
  key_vault_name = "kv-claims-p3-${var.resource_group_suffix}"
  storage_name   = lower("stclaimsp3${var.resource_group_suffix}")
  tags = merge(var.tags, {
    project = "claims-modernization"
    phase   = "3-blob-storage"
  })
}

resource "azurerm_resource_group" "this" {
  name     = "rg-claims-phase3-${var.resource_group_suffix}"
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

module "storage" {
  source = "../modules/storage-account"

  name                     = local.storage_name
  location                 = azurerm_resource_group.this.location
  resource_group_name      = azurerm_resource_group.this.name
  account_replication_type = var.storage_replication_type
  container_name           = "attachments"
  container_access_type    = "private"

  tags = local.tags
}

module "app_service" {
  source = "../modules/app-service"

  name                = local.app_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = var.app_service_sku

  # The SQL connection string and the Storage Account connection string are
  # both read from Key Vault via App Service Key Vault references (the
  # "@Microsoft.KeyVault(...)" values below) rather than the app calling the
  # Key Vault SDK directly -- App Service resolves them into plain
  # environment variables before the app starts, so no code change is
  # needed. The web app's managed identity is granted access to both
  # secrets below, via module.key_vault.access_object_ids.
  #
  # Storage__Provider=AzureBlob switches Program.cs to
  # AzureBlobFileStorageService, which reads/writes the Storage Account
  # below instead of each App Service instance's own local disk -- this is
  # the fix for the upload/download consistency bug demonstrated in
  # Phases 0-2.
  app_settings = {
    "ConnectionStrings__ClaimsDb"           = "@Microsoft.KeyVault(SecretUri=${module.key_vault.vault_uri}secrets/ClaimsDb-ConnectionString/)"
    "Storage__Provider"                     = "AzureBlob"
    "Storage__AzureBlob__ConnectionString"  = "@Microsoft.KeyVault(SecretUri=${module.key_vault.vault_uri}secrets/Storage-ConnectionString/)"
    "Storage__AzureBlob__ContainerName"     = module.storage.container_name
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
    "Storage-ConnectionString"  = module.storage.primary_connection_string
  }

  access_object_ids = [module.app_service.principal_id]

  tags = local.tags
}
