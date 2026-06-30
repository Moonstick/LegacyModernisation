variable "subscription_id" {
  type        = string
  description = "Azure subscription ID to deploy into."
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID, used for both Key Vaults and their access policies."
}

variable "location" {
  type        = string
  default     = "uksouth"
  description = "Primary Azure region. Hosts the primary App Service, the primary SQL Managed Instance, and (along with secondary_location) the RA-GRS storage account's primary endpoint."
}

variable "secondary_location" {
  type        = string
  default     = "ukwest"
  description = "Secondary Azure region. Hosts the secondary App Service and the secondary (failover partner) SQL Managed Instance. Must be a valid RA-GRS geo-replication pair for the primary region."
}

variable "resource_group_suffix" {
  type        = string
  description = "Suffix appended to resource names to keep them globally unique. Keep this short (<=6 chars) -- it feeds both Key Vault names (kv-claims-p6pri-<suffix> / kv-claims-p6sec-<suffix>), which have a 24-character limit."
}

variable "sql_admin_login" {
  type        = string
  default     = "claimsadmin"
  description = "Administrator login for both SQL Managed Instances (primary and secondary)."
}

variable "sql_admin_password" {
  type        = string
  sensitive   = true
  description = "Administrator password for both SQL Managed Instances (primary and secondary)."
}

variable "app_service_sku" {
  type        = string
  default     = "B1"
  description = "App Service Plan SKU, applied identically to both regional App Service Plans."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags merged into every resource created by this phase."
}
