variable "name" {
  type        = string
  description = "Storage account name; must be globally unique, <=24 characters, lowercase letters and numbers only."
}

variable "location" {
  type        = string
  description = "Azure region in which to create the storage account."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group in which to create the storage account."
}

variable "account_replication_type" {
  type        = string
  default     = "LRS"
  description = "Replication type for the storage account (e.g. LRS, RAGRS)."
}

variable "container_name" {
  type        = string
  default     = "attachments"
  description = "Name of the blob container created within the storage account."
}

variable "container_access_type" {
  type        = string
  default     = "private"
  description = "Access level of the blob container (private, blob, or container)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every resource created by this module."
}
