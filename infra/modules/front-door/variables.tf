variable "name" {
  type        = string
  description = "Name of the Front Door profile (must be globally unique)."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group in which to create the Front Door resources."
}

variable "sku_name" {
  type        = string
  default     = "Standard_AzureFrontDoor"
  description = "SKU name for the Front Door profile (Standard_AzureFrontDoor or Premium_AzureFrontDoor)."
}

variable "origins" {
  type = list(object({
    name      = string
    host_name = string
    priority  = optional(number, 1)
    weight    = optional(number, 1000)
  }))
  description = "List of origins (e.g. regional App Service hostnames) to add to the Front Door origin group."
}

variable "health_check_path" {
  type        = string
  default     = "/health"
  description = "Path used by the Front Door origin group health probe."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every resource created by this module."
}
