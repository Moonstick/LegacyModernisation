variable "subscription_id" {
  type        = string
  description = "Azure subscription ID to deploy into."
}

variable "location" {
  type        = string
  default     = "uksouth"
  description = "Azure region to deploy into."
}

variable "resource_group_suffix" {
  type        = string
  description = "Suffix appended to resource names to keep them globally unique, e.g. your initials or a short random string."
}

variable "ssh_public_key_path" {
  type        = string
  default     = "~/.ssh/claims_modernization.pub"
  description = "Path to the SSH public key used for VM administrator login."
}

variable "sql_admin_password" {
  type        = string
  sensitive   = true
  description = "SA password for the SQL Server instance installed on the VM. Must meet SQL Server's complexity requirements (8+ chars, upper+lower+digit+symbol)."
}

variable "git_tag" {
  type        = string
  default     = "phase-0-single-vm-baseline"
  description = "Git tag of this repo that cloud-init checks out and publishes on the VM."
}

variable "vm_size" {
  type        = string
  default     = "Standard_B2s"
  description = "Azure VM size. Phase 0 co-locates the web app and SQL Server, so this should be at least B2s."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags merged into every resource created by this phase."
}
