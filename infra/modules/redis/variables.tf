variable "name" {
  type        = string
  description = "Name of the Redis cache (must be globally unique)."
}

variable "location" {
  type        = string
  description = "Azure region in which to create the Redis cache."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group in which to create the Redis cache."
}

variable "sku_name" {
  type        = string
  default     = "Standard"
  description = "SKU name for the Redis cache (Basic, Standard, or Premium)."
}

variable "family" {
  type        = string
  default     = "C"
  description = "SKU family for the Redis cache (C for Basic/Standard, P for Premium)."
}

variable "capacity" {
  type        = number
  default     = 1
  description = "Size of the Redis cache, in family-specific units."
}

variable "enable_non_ssl_port" {
  type        = bool
  default     = false
  description = "Whether to enable the non-SSL (6379) port in addition to the SSL port."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every resource created by this module."
}
