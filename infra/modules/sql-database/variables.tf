variable "name" {
  type        = string
  description = "Logical SQL server name (must be globally unique)."
}

variable "database_name" {
  type        = string
  default     = "claimsdb"
  description = "Name of the SQL database created on the logical server."
}

variable "location" {
  type        = string
  description = "Azure region in which to create the SQL resources."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group in which to create the SQL resources."
}

variable "admin_login" {
  type        = string
  description = "Administrator login name for the SQL logical server."
}

variable "admin_password" {
  type        = string
  sensitive   = true
  description = "Administrator login password for the SQL logical server."
}

variable "sku_name" {
  type        = string
  default     = "S1"
  description = "SKU name for the SQL database (e.g. S1, P1, GP_S_Gen5_2)."
}

variable "max_size_gb" {
  type        = number
  default     = 20
  description = "Maximum size in GB of the SQL database."
}

variable "allow_azure_services" {
  type        = bool
  default     = true
  description = "Whether to add a firewall rule allowing other Azure services to access the SQL server."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every resource created by this module."
}
