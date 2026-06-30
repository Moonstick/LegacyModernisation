variable "name" {
  type        = string
  description = "Name of the SQL Managed Instance (must be globally unique)."
}

variable "location" {
  type        = string
  description = "Azure region in which to create the SQL Managed Instance."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group in which to create the SQL Managed Instance."
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnet for the managed instance; must be delegated to Microsoft.Sql/managedInstances."
}

variable "admin_login" {
  type        = string
  description = "Administrator login name for the managed instance."
}

variable "admin_password" {
  type        = string
  sensitive   = true
  description = "Administrator login password for the managed instance."
}

variable "sku_name" {
  type        = string
  default     = "GP_Gen5"
  description = "SKU name for the managed instance (e.g. GP_Gen5, BC_Gen5)."
}

variable "vcores" {
  type        = number
  default     = 4
  description = "Number of vCores allocated to the managed instance."
}

variable "storage_size_gb" {
  type        = number
  default     = 256
  description = "Storage size in GB allocated to the managed instance."
}

variable "enable_failover_group" {
  type        = bool
  default     = false
  description = "Whether to create a failover group pairing this managed instance with a partner instance."
}

variable "partner_managed_instance_id" {
  type        = string
  default     = ""
  description = "ID of the partner managed instance for the failover group; required when enable_failover_group is true."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every resource created by this module."
}
