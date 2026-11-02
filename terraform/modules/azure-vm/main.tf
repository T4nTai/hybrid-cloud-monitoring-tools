terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Public IP
resource "azurerm_public_ip" "vm" {
  name                = "${var.project_name}-${var.name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.name}-pip"
    }
  )
}

# Network Interface
resource "azurerm_network_interface" "vm" {
  name                = "${var.project_name}-${var.name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.name}-nic"
    }
  )
}

# Network Security Group
resource "azurerm_network_security_group" "vm" {
  name                = "${var.project_name}-${var.name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.name}-nsg"
    }
  )
}

# NSG Rules
resource "azurerm_network_security_rule" "rules" {
  count = length(var.nsg_rules)

  name                         = var.nsg_rules[count.index].name
  priority                     = var.nsg_rules[count.index].priority
  direction                    = var.nsg_rules[count.index].direction
  access                       = var.nsg_rules[count.index].access
  protocol                     = var.nsg_rules[count.index].protocol
  source_port_range            = var.nsg_rules[count.index].source_port_range
  destination_port_range       = var.nsg_rules[count.index].destination_port_range
  source_address_prefix        = try(var.nsg_rules[count.index].source_address_prefix, null)
  source_address_prefixes      = try(var.nsg_rules[count.index].source_address_prefixes, null)
  destination_address_prefix   = var.nsg_rules[count.index].destination_address_prefix
  resource_group_name          = var.resource_group_name
  network_security_group_name  = azurerm_network_security_group.vm.name
}

# Associate NSG với NIC
resource "azurerm_network_interface_security_group_association" "vm" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.project_name}-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.vm.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.name}"
    }
  )
}
