variable "name" {
  type        = string
  description = "Name used to derive the Log Analytics workspace and Application Insights resource names."
}

variable "location" {
  type        = string
  description = "Azure region in which to create the monitoring resources."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group in which to create the monitoring resources."
}

variable "retention_in_days" {
  type        = number
  default     = 30
  description = "Number of days to retain data in the Log Analytics workspace."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every resource created by this module."
}
