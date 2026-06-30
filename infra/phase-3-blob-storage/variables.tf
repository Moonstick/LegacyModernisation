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
  description = "Azure region to deploy into."
}

variable "resource_group_suffix" {
  type        = string
  description = "Suffix appended to resource names to keep them globally unique. Keep this short (<=6 chars) -- it also feeds the Key Vault name, which has a 24-character limit."
}

variable "sql_admin_login" {
  type        = string
  default     = "claimsadmin"
  description = "Administrator login for the Azure SQL Database logical server."
}

variable "sql_admin_password" {
  type        = string
  sensitive   = true
  description = "Administrator password for the Azure SQL Database logical server."
}

variable "app_service_sku" {
  type        = string
  default     = "B1"
  description = "App Service Plan SKU. Use at least S1 if you want autoscaling to have headroom to demonstrate under load."
}

variable "storage_replication_type" {
  type        = string
  default     = "LRS"
  description = "Replication type for the Storage Account holding claim attachments (e.g. LRS, RAGRS)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags merged into every resource created by this phase."
}
