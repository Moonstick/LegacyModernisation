locals {
  name_prefix           = "claims-phase5-${var.resource_group_suffix}"
  app_name              = "${local.name_prefix}-app"
  key_vault_name        = "kv-claims-p5-${var.resource_group_suffix}"
  storage_name          = lower("stclaimsp5${var.resource_group_suffix}")
  redis_name            = "${local.name_prefix}-redis"
  sql_mi_primary_name   = "${local.name_prefix}-sqlmi-pri"
  sql_mi_secondary_name = "${local.name_prefix}-sqlmi-sec"
  tags = merge(var.tags, {
    project = "claims-modernization"
    phase   = "5-managed-instance"
  })
}

# A single resource group covers both regions used by this phase -- resource
# groups aren't region-locked, only the VNets/subnets inside them are. The
# primary region (var.location) hosts the app tier (App Service, Storage,
# Redis, monitoring, Key Vault) plus the primary SQL Managed Instance; the
# secondary region (var.secondary_location) hosts only the DR SQL Managed
# Instance and its own VNet/subnet.
resource "azurerm_resource_group" "this" {
  name     = "rg-claims-phase5-${var.resource_group_suffix}"
  location = var.location
  tags     = local.tags
}

# SQL Managed Instance is a regional resource and requires its own VNet in
# that region; the delegated MI subnet must otherwise be empty per Azure's
# rules, so it gets nothing else placed in it. One network module instance
# per region.
module "network_primary" {
  source = "../modules/network"

  name_prefix         = "${local.name_prefix}-pri"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name

  subnets = {
    mi = {
      address_prefixes = ["10.5.0.0/24"]
      delegation       = "Microsoft.Sql/managedInstances"
    }
  }

  tags = local.tags
}

module "network_secondary" {
  source = "../modules/network"

  name_prefix         = "${local.name_prefix}-sec"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.6.0.0/16"]

  subnets = {
    mi = {
      address_prefixes = ["10.6.0.0/24"]
      delegation       = "Microsoft.Sql/managedInstances"
    }
  }

  tags = local.tags
}

# The shared network module gives every subnet (including the MI subnet) an
# NSG with no rules beyond Azure's defaults. SQL Managed Instance requires
# its subnet to allow specific management-plane traffic (Azure Active
# Directory, Azure Storage, Microsoft Sql Management endpoints on ports
# 443/12000) for the platform's own health/control operations -- those rules
# are deliberately not modeled here; see the README's "Known limitations"
# section. The single rule added below is only the one this phase actually
# needs in order to demonstrate the public-data-endpoint simplification
# described in the README and in the locals block further down: inbound
# 3342 (the MI public endpoint port) from anywhere, mirroring the
# already-documented "open to source *" simplification used elsewhere in
# this repo (e.g. Phase 0/1 NSG rules).
resource "azurerm_network_security_rule" "allow_mi_public_endpoint_primary" {
  name                        = "AllowSqlMiPublicEndpointInbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3342"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = "${local.name_prefix}-pri-mi-nsg"

  depends_on = [module.network_primary]
}

resource "azurerm_network_security_rule" "allow_mi_public_endpoint_secondary" {
  name                        = "AllowSqlMiPublicEndpointInbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3342"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = "${local.name_prefix}-sec-mi-nsg"

  depends_on = [module.network_secondary]
}

module "monitoring" {
  source = "../modules/monitoring"

  name                = local.name_prefix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  tags = local.tags
}

# Secondary SQL Managed Instance first (no failover group of its own --
# enable_failover_group defaults to false), so its ID is available to feed
# into the primary's partner_managed_instance_id below.
module "sql_mi_secondary" {
  source = "../modules/sql-managed-instance"

  name                = local.sql_mi_secondary_name
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = module.network_secondary.subnet_ids["mi"]
  admin_login         = var.sql_admin_login
  admin_password      = var.sql_admin_password
  sku_name            = var.sql_mi_sku_name
  vcores              = var.sql_mi_vcores
  storage_size_gb     = var.sql_mi_storage_size_gb

  tags = local.tags
}

# Primary SQL Managed Instance, paired with the secondary via an
# auto-failover group (read_write_endpoint_failover_policy = Automatic,
# inherited from the sql-managed-instance module's own defaults). The app
# tier always talks to the primary's fqdn below; in a real failover the
# failover group's listener endpoint would redirect transparently, but this
# scaffold builds the connection string from the primary instance's own
# fqdn directly (see the locals block below) rather than the failover
# group's listener -- see the README for why.
module "sql_mi_primary" {
  source = "../modules/sql-managed-instance"

  name                = local.sql_mi_primary_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = module.network_primary.subnet_ids["mi"]
  admin_login         = var.sql_admin_login
  admin_password      = var.sql_admin_password
  sku_name            = var.sql_mi_sku_name
  vcores              = var.sql_mi_vcores
  storage_size_gb     = var.sql_mi_storage_size_gb

  enable_failover_group       = true
  partner_managed_instance_id = module.sql_mi_secondary.mi_id

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

locals {
  # The sql-managed-instance module has no connection_string output (unlike
  # sql-database), so it's built here from the primary instance's fqdn.
  #
  # KNOWN LIMITATION -- public data endpoint, not private VNet integration:
  # Azure SQL Managed Instance is only reachable on its public data endpoint
  # (port 3342) from outside its own VNet, or privately (port 1433) from
  # something that is VNet-integrated into the MI's VNet (or peered to it).
  # The shared `app-service` module in this repo does not currently expose a
  # VNet integration variable (checked infra/modules/app-service/variables.tf
  # -- there is none), and this phase must not modify that shared module.
  # Production Azure architecture would put App Service on regional VNet
  # integration so it could reach the MI privately on 1433; that's out of
  # scope here. As a documented simplification (same spirit as the Phase 0/1
  # "open to source *" NSG rules), this connection string instead targets the
  # MI's public data endpoint on port 3342.
  #
  # This also means a real `terraform apply` of this phase will NOT actually
  # let the app connect out of the box: azurerm_mssql_managed_instance
  # defaults public_data_endpoint_enabled to false, and the
  # sql-managed-instance module doesn't expose a toggle for it either (by
  # design -- it's a shared, frozen module). Enabling the public endpoint
  # would require extending that module, which is outside this phase's
  # remit. This is named here, in the README, and in deploy.sh rather than
  # silently worked around.
  sql_mi_connection_string = "Server=tcp:${module.sql_mi_primary.fqdn},3342;Initial Catalog=claimsdb;Persist Security Info=False;User ID=${var.sql_admin_login};Password=${var.sql_admin_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
}

module "app_service" {
  source = "../modules/app-service"

  name                = local.app_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = var.app_service_sku

  # As in Phases 3/4, all three connection strings are read from Key Vault
  # via App Service Key Vault references -- no code change is needed.
  # Storage and Redis are wired exactly as in Phase 4 (single region,
  # unchanged by this phase). ConnectionStrings__ClaimsDb now points at the
  # primary SQL Managed Instance's public data endpoint (port 3342) instead
  # of Azure SQL Database -- see the locals block above and the README for
  # the public-endpoint-vs-VNet-integration limitation this implies.
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
    "ClaimsDb-ConnectionString" = local.sql_mi_connection_string
    "Storage-ConnectionString"  = module.storage.primary_connection_string
    "Redis-ConnectionString"    = module.redis.connection_string
  }

  access_object_ids = [module.app_service.principal_id]

  tags = local.tags
}
