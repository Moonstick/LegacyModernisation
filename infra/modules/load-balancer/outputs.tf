output "public_ip_address" {
  value       = azurerm_public_ip.this.ip_address
  description = "Public IP address of the load balancer frontend."
}

output "backend_address_pool_id" {
  value       = azurerm_lb_backend_address_pool.this.id
  description = "ID of the load balancer's backend address pool."
}

output "lb_id" {
  value       = azurerm_lb.this.id
  description = "ID of the created load balancer."
}
