resource "azurerm_public_ip" "this" {
  name                = "${var.name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_lb" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "${var.name}-frontend"
    public_ip_address_id = azurerm_public_ip.this.id
  }
}

resource "azurerm_lb_backend_address_pool" "this" {
  name            = "${var.name}-backend-pool"
  loadbalancer_id = azurerm_lb.this.id
}

resource "azurerm_lb_probe" "this" {
  name            = "${var.name}-probe"
  loadbalancer_id = azurerm_lb.this.id
  protocol        = "Http"
  port            = var.health_probe_port
  request_path    = var.health_probe_path
}

resource "azurerm_lb_rule" "this" {
  name                           = "${var.name}-rule"
  loadbalancer_id                = azurerm_lb.this.id
  protocol                       = "Tcp"
  frontend_port                  = var.frontend_port
  backend_port                   = var.backend_port
  frontend_ip_configuration_name = azurerm_lb.this.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.this.id]
  probe_id                       = azurerm_lb_probe.this.id
}

resource "azurerm_network_interface_backend_address_pool_association" "this" {
  for_each = { for nic in var.backend_nics : nic.nic_id => nic }

  network_interface_id   = each.value.nic_id
  ip_configuration_name  = each.value.ip_configuration_name
  backend_address_pool_id = azurerm_lb_backend_address_pool.this.id
}
