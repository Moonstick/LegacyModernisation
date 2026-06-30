variable "name" {
  type        = string
  description = "Name of the load balancer; also used to derive names of associated resources (public IP, backend pool, probe, rule)."
}

variable "location" {
  type        = string
  description = "Azure region in which to create the load balancer."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group in which to create the load balancer."
}

variable "backend_nics" {
  type = list(object({
    nic_id                = string
    ip_configuration_name = string
  }))
  default     = []
  description = "List of backend VM network interfaces (NIC id plus the name of the IP configuration on that NIC) to associate with the backend address pool."
}

variable "health_probe_port" {
  type        = number
  default     = 80
  description = "Port used by the load balancer health probe."
}

variable "health_probe_path" {
  type        = string
  default     = "/health"
  description = "HTTP path used by the load balancer health probe."
}

variable "frontend_port" {
  type        = number
  default     = 80
  description = "Frontend port the load balancing rule listens on."
}

variable "backend_port" {
  type        = number
  default     = 80
  description = "Backend port traffic is forwarded to on the backend pool members."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every resource created by this module."
}
