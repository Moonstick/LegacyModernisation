variable "name" {
  type        = string
  description = "Name of the virtual machine; also used to derive names of associated resources (NIC, public IP)."
}

variable "location" {
  type        = string
  description = "Azure region in which to create the virtual machine."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group in which to create the virtual machine."
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnet the virtual machine's network interface will be attached to."
}

variable "vm_size" {
  type        = string
  default     = "Standard_B2s"
  description = "Azure VM size SKU."
}

variable "admin_username" {
  type        = string
  default     = "azureadmin"
  description = "Administrator username for SSH login."
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key content used for administrator authentication (password authentication is disabled)."
}

variable "custom_data" {
  type        = string
  default     = ""
  description = "Raw (not base64-encoded) cloud-init YAML to apply on boot; this module base64-encodes it internally before passing it to Azure."
}

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "Whether to create and assign a Standard SKU public IP to the virtual machine."
}

variable "os_disk_size_gb" {
  type        = number
  default     = 64
  description = "Size in GB of the OS disk."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every resource created by this module."
}
