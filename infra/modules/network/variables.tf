variable "name_prefix" {
  type        = string
  description = "Prefix applied to all networking resource names created by this module."
}

variable "location" {
  type        = string
  description = "Azure region in which to create the networking resources."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group in which to create the networking resources."
}

variable "address_space" {
  type        = list(string)
  default     = ["10.0.0.0/16"]
  description = "Address space assigned to the virtual network."
}

variable "subnets" {
  type = map(object({
    address_prefixes = list(string)
    delegation        = optional(string)
  }))
  description = "Map of subnets to create, keyed by logical name. 'delegation', when set, is an Azure service delegation name (e.g. Microsoft.Web/serverFarms or Microsoft.Sql/managedInstances)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every resource created by this module."
}
