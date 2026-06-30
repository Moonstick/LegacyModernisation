# Phase 6 -- multi-region: Azure Front Door fronting two fully-provisioned
# regional stacks (App Service + Key Vault + Monitoring + Redis in each of
# var.location and var.secondary_location), a primary/secondary SQL Managed
# Instance failover group spanning both regions, and one RA-GRS storage
# account shared by both. Everything lives in a single resource group so
# deploy.sh/teardown.sh manage the whole multi-region footprint atomically,
# per this repo's per-phase blast-radius isolation convention.

locals {
  name_prefix = "claims-phase6-${var.resource_group_suffix}"

  primary_prefix   = "${local.name_prefix}-pri"
  secondary_prefix = "${local.name_prefix}-sec"

  primary_key_vault_name   = "kv-claims-p6pri-${var.resource_group_suffix}"
  secondary_key_vault_name = "kv-claims-p6sec-${var.resource_group_suffix}"

  primary_mi_subnet_cidr   = "10.10.0.0/24"
  secondary_mi_subnet_cidr = "10.20.0.0/24"

  tags = merge(var.tags, {
    project = "claims-modernization"
    phase   = "6-multi-region"
  })

  # The sql-managed-instance module does not expose a stable failover-group
  # listener/DNS name as an output (confirmed by reading
  # infra/modules/sql-managed-instance/{main,outputs}.tf) -- only mi_id,
  # fqdn (the raw per-instance FQDN) and failover_group_id. A real
  # production setup would prefer the failover group's own read-write
  # listener endpoint so the connection string keeps working transparently
  # across a failover, but that endpoint isn't surfaced anywhere we can
  # reference without modifying the shared module (out of scope -- the
  # module is frozen for this phase). So both regions' App Service connect
  # to the PRIMARY MI's raw fqdn on port 3342 (SQL MI's public data
  # endpoint port). After a real failover promotes the secondary, this
  # connection string would need to be updated by hand (or the module
  # extended to expose the listener) -- this is a documented limitation,
  # not an oversight. See README.md for the full explanation.
  #
  # Connecting via the public data endpoint at all is itself a simplification:
  # the shared sql-managed-instance module does not expose
  # public_data_endpoint_enabled, so this assumes it is enabled on the MI.
  # Production wiring would instead use private VNet integration from each
  # region's App Service to the MI rather than the public endpoint.
  sql_connection_string = "Server=tcp:${module.sql_primary.fqdn},3342;Initial Catalog=claimsdb;Persist Security Info=False;User ID=${var.sql_admin_login};Password=${var.sql_admin_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
}

resource "azurerm_resource_group" "this" {
  name     = "rg-claims-phase6-${var.resource_group_suffix}"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Networking -- one VNet per region, each with a subnet delegated to
# Microsoft.Sql/managedInstances for that region's Managed Instance. Same
# delegated-subnet pattern as Phase 5.
# ---------------------------------------------------------------------------

module "network_primary" {
  source = "../modules/network"

  name_prefix         = local.primary_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name

  address_space = ["10.10.0.0/16"]
  subnets = {
    mi = {
      address_prefixes = [local.primary_mi_subnet_cidr]
      delegation       = "Microsoft.Sql/managedInstances"
    }
  }

  tags = local.tags
}

module "network_secondary" {
  source = "../modules/network"

  name_prefix         = local.secondary_prefix
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.this.name

  address_space = ["10.20.0.0/16"]
  subnets = {
    mi = {
      address_prefixes = [local.secondary_mi_subnet_cidr]
      delegation       = "Microsoft.Sql/managedInstances"
    }
  }

  tags = local.tags
}

# SQL Managed Instance requires its delegated subnet to allow inbound
# traffic on 3342 (the public data endpoint port) -- same public-endpoint
# simplification caveat as Phase 5: this opens the port at the NSG level so
# the example is reachable without standing up private VNet integration
# from App Service. Production wiring would prefer that over a public
# endpoint entirely.
resource "azurerm_network_security_rule" "allow_mi_public_endpoint_primary" {
  name                        = "AllowSqlMiPublicEndpoint"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3342"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = "${local.primary_prefix}-mi-nsg"

  depends_on = [module.network_primary]
}

resource "azurerm_network_security_rule" "allow_mi_public_endpoint_secondary" {
  name                        = "AllowSqlMiPublicEndpoint"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3342"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = "${local.secondary_prefix}-mi-nsg"

  depends_on = [module.network_secondary]
}

# ---------------------------------------------------------------------------
# SQL Managed Instance -- primary/secondary pair joined by a failover group,
# same pattern as Phase 5. NOTE: SQL MI provisioning takes 4-6 hours in real
# Azure (see the module's own comment) -- this is a code-only scaffold.
# ---------------------------------------------------------------------------

module "sql_secondary" {
  source = "../modules/sql-managed-instance"

  name                  = "${local.secondary_prefix}-mi"
  location              = var.secondary_location
  resource_group_name   = azurerm_resource_group.this.name
  subnet_id             = module.network_secondary.subnet_ids["mi"]
  admin_login           = var.sql_admin_login
  admin_password        = var.sql_admin_password
  enable_failover_group = false

  tags = local.tags
}

module "sql_primary" {
  source = "../modules/sql-managed-instance"

  name                        = "${local.primary_prefix}-mi"
  location                    = var.location
  resource_group_name         = azurerm_resource_group.this.name
  subnet_id                   = module.network_primary.subnet_ids["mi"]
  admin_login                 = var.sql_admin_login
  admin_password              = var.sql_admin_password
  enable_failover_group       = true
  partner_managed_instance_id = module.sql_secondary.mi_id

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Storage -- one RA-GRS account, shared by both regions. RA-GRS means the
# secondary region's read-only endpoint stays readable even if the primary
# region's storage endpoint is down, satisfying this phase's "storage
# readable from both regions" requirement without standing up two separate
# accounts. (azurerm's account_replication_type value is "RAGRS" -- no
# hyphen; "RA-GRS" is only the Azure portal's display name for the same
# replication type.)
# ---------------------------------------------------------------------------

module "storage" {
  source = "../modules/storage-account"

  name                     = "stclaimsp6${var.resource_group_suffix}"
  location                 = azurerm_resource_group.this.location
  resource_group_name      = azurerm_resource_group.this.name
  account_replication_type = "RAGRS"

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Redis -- one cache per region (cache-aside, not replicated). A regional
# failover loses whatever sessions/cache entries were only in the failed
# region's cache; users re-authenticate against the surviving region. See
# README.md for why this is a deliberate trade-off, not a bug.
# ---------------------------------------------------------------------------

module "redis_primary" {
  source = "../modules/redis"

  name                = "${local.primary_prefix}-redis"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name

  tags = local.tags
}

module "redis_secondary" {
  source = "../modules/redis"

  name                = "${local.secondary_prefix}-redis"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.this.name

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Monitoring -- one Log Analytics workspace + Application Insights per
# region, so each region's telemetry (and any later failover investigation)
# can be inspected independently of the other region's health.
# ---------------------------------------------------------------------------

module "monitoring_primary" {
  source = "../modules/monitoring"

  name                = local.primary_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name

  tags = local.tags
}

module "monitoring_secondary" {
  source = "../modules/monitoring"

  name                = local.secondary_prefix
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.this.name

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Key Vault -- one per region, each holding that region's own copy of the
# secrets. ClaimsDb-ConnectionString and Storage-ConnectionString are
# identical in both vaults (both regions point at the primary MI and the
# shared RA-GRS storage account); Redis-ConnectionString differs because
# each region has its own cache.
# ---------------------------------------------------------------------------

module "key_vault_primary" {
  source = "../modules/key-vault"

  name                = local.primary_key_vault_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = var.tenant_id

  secrets = {
    "ClaimsDb-ConnectionString" = local.sql_connection_string
    "Storage-ConnectionString"  = module.storage.primary_connection_string
    "Redis-ConnectionString"    = module.redis_primary.connection_string
  }

  access_object_ids = [module.app_service_primary.principal_id]

  tags = local.tags
}

module "key_vault_secondary" {
  source = "../modules/key-vault"

  name                = local.secondary_key_vault_name
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = var.tenant_id

  secrets = {
    "ClaimsDb-ConnectionString" = local.sql_connection_string
    "Storage-ConnectionString"  = module.storage.primary_connection_string
    "Redis-ConnectionString"    = module.redis_secondary.connection_string
  }

  access_object_ids = [module.app_service_secondary.principal_id]

  tags = local.tags
}

# ---------------------------------------------------------------------------
# App Service -- one per region. Both regions read the same ClaimsDb and
# Storage secrets (shared primary MI / shared RA-GRS storage account) but
# each reads its own region's Redis secret, all via Key Vault references
# resolved by App Service itself -- no code change needed, same as Phase 2.
# ---------------------------------------------------------------------------

module "app_service_primary" {
  source = "../modules/app-service"

  name                = "${local.primary_prefix}-app"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = var.app_service_sku

  app_settings = {
    "ConnectionStrings__ClaimsDb"           = "@Microsoft.KeyVault(SecretUri=${module.key_vault_primary.vault_uri}secrets/ClaimsDb-ConnectionString/)"
    "Storage__Provider"                     = "AzureBlob"
    "Storage__AzureBlob__ConnectionString"  = "@Microsoft.KeyVault(SecretUri=${module.key_vault_primary.vault_uri}secrets/Storage-ConnectionString/)"
    "Storage__AzureBlob__ContainerName"     = module.storage.container_name
    "Redis__ConnectionString"               = "@Microsoft.KeyVault(SecretUri=${module.key_vault_primary.vault_uri}secrets/Redis-ConnectionString/)"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = module.monitoring_primary.app_insights_connection_string
  }

  tags = local.tags
}

module "app_service_secondary" {
  source = "../modules/app-service"

  name                = "${local.secondary_prefix}-app"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = var.app_service_sku

  app_settings = {
    "ConnectionStrings__ClaimsDb"           = "@Microsoft.KeyVault(SecretUri=${module.key_vault_secondary.vault_uri}secrets/ClaimsDb-ConnectionString/)"
    "Storage__Provider"                     = "AzureBlob"
    "Storage__AzureBlob__ConnectionString"  = "@Microsoft.KeyVault(SecretUri=${module.key_vault_secondary.vault_uri}secrets/Storage-ConnectionString/)"
    "Storage__AzureBlob__ContainerName"     = module.storage.container_name
    "Redis__ConnectionString"               = "@Microsoft.KeyVault(SecretUri=${module.key_vault_secondary.vault_uri}secrets/Redis-ConnectionString/)"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = module.monitoring_secondary.app_insights_connection_string
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Front Door -- global entry point, active/active across both regions. Both
# origins get priority 1 (rather than a 1/2 active/passive split) because
# both regions are fully provisioned and serving traffic, not a cold
# standby -- Front Door load-balances across both, and its health probe
# (default path /health, interval baked into the front-door module) simply
# stops routing to whichever origin fails its probe. That gives automatic
# regional failover "for free" as a side effect of normal load balancing,
# without an explicit failover step.
# ---------------------------------------------------------------------------

module "front_door" {
  source = "../modules/front-door"

  name                = "${local.name_prefix}-fd"
  resource_group_name = azurerm_resource_group.this.name

  origins = [
    {
      name      = "${local.primary_prefix}-origin"
      host_name = module.app_service_primary.default_hostname
      priority  = 1
    },
    {
      name      = "${local.secondary_prefix}-origin"
      host_name = module.app_service_secondary.default_hostname
      priority  = 1
    },
  ]

  health_check_path = "/health"

  tags = local.tags
}
