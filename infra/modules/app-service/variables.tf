variable "name" {
  type        = string
  description = "Name of the Linux Web App; also used to derive the App Service Plan name."
}

variable "location" {
  type        = string
  description = "Azure region in which to create the App Service resources."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group in which to create the App Service resources."
}

variable "sku_name" {
  type        = string
  default     = "B1"
  description = "App Service Plan SKU name (e.g. B1, S1, P1v3)."
}

variable "app_settings" {
  type        = map(string)
  default     = {}
  description = "Application settings (environment variables) applied to the web app."
}

variable "connection_strings" {
  type = map(object({
    type  = string
    value = string
  }))
  default     = {}
  description = "Connection strings applied to the web app, keyed by connection string name."
}

variable "dotnet_version" {
  type        = string
  default     = "8.0"
  description = ".NET version for the Linux web app's application stack."
}

variable "always_on" {
  type        = bool
  default     = true
  description = "Whether the web app should be kept loaded even when there is no traffic."
}

variable "health_check_path" {
  type        = string
  default     = "/health"
  description = "Path App Service pings to determine instance health."
}

variable "autoscale_min" {
  type        = number
  default     = 1
  description = "Minimum number of instances when autoscaling is enabled."
}

variable "autoscale_max" {
  type        = number
  default     = 3
  description = "Maximum number of instances when autoscaling is enabled."
}

variable "autoscale_default" {
  type        = number
  default     = 1
  description = "Default number of instances when autoscaling is enabled."
}

variable "enable_autoscale" {
  type        = bool
  default     = true
  description = "Whether to create an autoscale setting for the App Service Plan."
}

variable "identity_type" {
  type        = string
  default     = "SystemAssigned"
  description = "Type of managed identity assigned to the web app."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every resource created by this module."
}
