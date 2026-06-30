variable "name" {
  type        = string
  description = "Name of the Key Vault (must be globally unique)."
}

variable "location" {
  type        = string
  description = "Azure region in which to create the Key Vault."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group in which to create the Key Vault."
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID used for the Key Vault and its access policies."
}

variable "sku_name" {
  type        = string
  default     = "standard"
  description = "SKU name for the Key Vault (standard or premium)."
}

variable "secrets" {
  type        = map(string)
  default     = {}
  sensitive   = true
  description = "Map of secret name to secret value to store in the Key Vault."
}

variable "access_object_ids" {
  type        = list(string)
  default     = []
  description = "List of Azure AD object IDs (e.g. an App Service managed identity principal_id) to grant Get/List/Set secret permissions on the Key Vault."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every resource created by this module."
}
