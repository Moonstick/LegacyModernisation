variable "subscription_id" {
  type        = string
  description = "Azure subscription ID to deploy into."
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID, used for the Key Vault and its access policies."
}

variable "location" {
  type        = string
  default     = "uksouth"
  description = "Azure region for the primary SQL Managed Instance and the (single-region) App Service, Storage Account, Redis cache, and monitoring resources."
}

variable "secondary_location" {
  type        = string
  default     = "ukwest"
  description = "Azure region for the secondary (DR) SQL Managed Instance paired into the auto-failover group with the primary."
}

variable "resource_group_suffix" {
  type        = string
  description = "Suffix appended to resource names to keep them globally unique. Keep this short (<=6 chars) -- it also feeds the Key Vault name, which has a 24-character limit."
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
  description = "App Service Plan SKU. Use at least S1 if you want autoscaling to have headroom to demonstrate under load."
}

variable "storage_replication_type" {
  type        = string
  default     = "LRS"
  description = "Replication type for the attachments storage account (e.g. LRS, RAGRS)."
}

variable "redis_sku_name" {
  type        = string
  default     = "Standard"
  description = "SKU name for the Redis cache (Basic, Standard, or Premium). Standard demonstrates HA (primary/replica) better than Basic."
}

variable "redis_family" {
  type        = string
  default     = "C"
  description = "SKU family for the Redis cache (C for Basic/Standard, P for Premium)."
}

variable "redis_capacity" {
  type        = number
  default     = 1
  description = "Size of the Redis cache, in family-specific units."
}

variable "sql_mi_sku_name" {
  type        = string
  default     = "GP_Gen5"
  description = "SKU name for both SQL Managed Instances (e.g. GP_Gen5, BC_Gen5)."
}

variable "sql_mi_vcores" {
  type        = number
  default     = 4
  description = "Number of vCores allocated to each SQL Managed Instance."
}

variable "sql_mi_storage_size_gb" {
  type        = number
  default     = 256
  description = "Storage size in GB allocated to each SQL Managed Instance."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags merged into every resource created by this phase."
}
