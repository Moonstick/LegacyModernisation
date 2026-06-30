locals {
  name_prefix = "claims-phase0-${var.resource_group_suffix}"
  tags = merge(var.tags, {
    project = "claims-modernization"
    phase   = "0-single-vm"
  })
}

resource "azurerm_resource_group" "this" {
  name     = "rg-claims-phase0-${var.resource_group_suffix}"
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "../modules/network"

  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  subnets = {
    app = { address_prefixes = ["10.0.1.0/24"] }
  }

  tags = local.tags
}

module "vm" {
  source = "../modules/linux-vm"

  name                = "${local.name_prefix}-vm"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = module.network.subnet_ids["app"]
  vm_size             = var.vm_size
  ssh_public_key      = file(var.ssh_public_key_path)
  assign_public_ip    = true

  custom_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    git_tag            = var.git_tag
    sql_admin_password = var.sql_admin_password
  })

  tags = local.tags
}

# The network module's NSG has no rules beyond Azure's defaults (which deny
# all internet inbound), so HTTP and SSH need to be opened explicitly here.
resource "azurerm_network_security_rule" "allow_http" {
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
  network_security_group_name = "${local.name_prefix}-app-nsg"

  depends_on = [module.network]
}

resource "azurerm_network_security_rule" "allow_ssh" {
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
  network_security_group_name = "${local.name_prefix}-app-nsg"

  depends_on = [module.network]
}
