locals {
  name_prefix    = "claims-phase4-${var.resource_group_suffix}"
  app_name       = "${local.name_prefix}-app"
  key_vault_name = "kv-claims-p4-${var.resource_group_suffix}"
  storage_name   = lower("stclaimsp4${var.resource_group_suffix}")
  redis_name     = "${local.name_prefix}-redis"
  tags = merge(var.tags, {
    project = "claims-modernization"
    phase   = "4-redis-session"
  })
}

resource "azurerm_resource_group" "this" {
  name     = "rg-claims-phase4-${var.resource_group_suffix}"
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

module "redis" {
  source = "../modules/redis"

  name                = local.redis_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = var.redis_sku_name
  family              = var.redis_family
  capacity            = var.redis_capacity
  enable_non_ssl_port = false

  tags = local.tags
}

module "app_service" {
  source = "../modules/app-service"

  name                = local.app_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = var.app_service_sku

  # The SQL, Storage Account, and Redis connection strings are all read from
  # Key Vault via App Service Key Vault references (the
  # "@Microsoft.KeyVault(...)" values below) rather than the app calling the
  # Key Vault SDK directly -- App Service resolves them into plain
  # environment variables before the app starts, so no code change is
  # needed. The web app's managed identity is granted access to all three
  # secrets below, via module.key_vault.access_object_ids.
  #
  # Storage__Provider stays AzureBlob (same fix as Phase 3 -- don't regress
  # the upload/download consistency bug).
  #
  # Redis__ConnectionString is now non-empty, which switches Program.cs from
  # AddDistributedMemoryCache() to AddStackExchangeRedisCache() -- ASP.NET
  # Core session state is now backed by a single shared Redis cache instead
  # of each App Service instance's own in-memory store, fixing the "Recently
  # Viewed" session-consistency bug demonstrated since Phase 1.
  app_settings = {
    "ConnectionStrings__ClaimsDb"           = "@Microsoft.KeyVault(SecretUri=${module.key_vault.vault_uri}secrets/ClaimsDb-ConnectionString/)"
    "Storage__Provider"                     = "AzureBlob"
    "Storage__AzureBlob__ConnectionString"  = "@Microsoft.KeyVault(SecretUri=${module.key_vault.vault_uri}secrets/Storage-ConnectionString/)"
    "Storage__AzureBlob__ContainerName"     = module.storage.container_name
    "Redis__ConnectionString"               = "@Microsoft.KeyVault(SecretUri=${module.key_vault.vault_uri}secrets/Redis-ConnectionString/)"
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
    "Redis-ConnectionString"    = module.redis.connection_string
  }

  access_object_ids = [module.app_service.principal_id]

  tags = local.tags
}
