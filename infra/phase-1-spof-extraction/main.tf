locals {
  name_prefix     = "claims-phase1-${var.resource_group_suffix}"
  web_subnet_cidr = "10.0.1.0/24"
  tags = merge(var.tags, {
    project = "claims-modernization"
    phase   = "1-spof-extraction"
  })
}

resource "azurerm_resource_group" "this" {
  name     = "rg-claims-phase1-${var.resource_group_suffix}"
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "../modules/network"

  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  subnets = {
    web = { address_prefixes = [local.web_subnet_cidr] }
    db  = { address_prefixes = ["10.0.2.0/24"] }
  }

  tags = local.tags
}

resource "azurerm_availability_set" "web" {
  name                         = "${local.name_prefix}-web-avset"
  location                     = azurerm_resource_group.this.location
  resource_group_name          = azurerm_resource_group.this.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
  managed                      = true

  tags = local.tags
}

# SQL Server lives on its own VM, separate from the web tier, but is still a
# single instance -- extracting it removes the "one box does everything"
# bottleneck without adding DB redundancy. That's Phase 5's job.
module "db_vm" {
  source = "../modules/linux-vm"

  name                = "${local.name_prefix}-db-vm"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = module.network.subnet_ids["db"]
  vm_size             = var.db_vm_size
  ssh_public_key      = file(var.ssh_public_key_path)
  assign_public_ip    = true

  custom_data = templatefile("${path.module}/cloud-init-db.yaml.tftpl", {
    sql_admin_password = var.sql_admin_password
  })

  tags = local.tags
}

# Two interchangeable web instances spread across an availability set, with
# no public IP of their own -- all inbound traffic arrives via the load
# balancer below. Each one still keeps uploaded files on its own local disk
# and session state in its own in-memory store, which is exactly the SPOF
# this phase's consistency-check load test is designed to expose.
module "web_vm" {
  source   = "../modules/linux-vm"
  for_each = toset(["1", "2"])

  name                = "${local.name_prefix}-web-vm-${each.key}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = module.network.subnet_ids["web"]
  vm_size             = var.web_vm_size
  ssh_public_key      = file(var.ssh_public_key_path)
  assign_public_ip    = false
  availability_set_id = azurerm_availability_set.web.id

  custom_data = templatefile("${path.module}/cloud-init-web.yaml.tftpl", {
    git_tag            = var.git_tag
    sql_admin_password = var.sql_admin_password
    db_private_ip      = module.db_vm.private_ip_address
  })

  tags = local.tags
}

module "lb" {
  source = "../modules/load-balancer"

  name                = "${local.name_prefix}-lb"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  backend_nics = [
    for vm in module.web_vm : {
      nic_id                = vm.network_interface_id
      ip_configuration_name = "internal"
    }
  ]

  health_probe_port = 80
  health_probe_path = "/health"
  frontend_port     = 80
  backend_port      = 80

  tags = local.tags
}

# Neither subnet's NSG has any rules beyond Azure's defaults (deny all
# internet inbound; a Standard SKU load balancer also requires an explicit
# NSG allow -- it does not get the Basic SKU's implicit AzureLoadBalancer
# allow on its own), so the ports each tier actually needs are opened here.
resource "azurerm_network_security_rule" "allow_http_web" {
  name                        = "AllowHttpInbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = "${local.name_prefix}-web-nsg"

  depends_on = [module.network]
}

resource "azurerm_network_security_rule" "allow_sql_from_web" {
  name                        = "AllowSqlFromWebSubnet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = local.web_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = "${local.name_prefix}-db-nsg"

  depends_on = [module.network]
}

resource "azurerm_network_security_rule" "allow_ssh_db" {
  name                        = "AllowSshInbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = "${local.name_prefix}-db-nsg"

  depends_on = [module.network]
}
