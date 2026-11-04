# =============================================================================
# Azure Central VM — Neutral Observer cho Hybrid Cloud Monitoring
# Chứa InfluxDB + Chronograf (TICK Stack), không tham gia benchmark
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group — use existing NT531
data "azurerm_resource_group" "central" {
  name = "NT531"
}

# Virtual Network
resource "azurerm_virtual_network" "central" {
  name                = "${var.project_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.azure_region # Use var instead of RG location to comply with policy
  resource_group_name = data.azurerm_resource_group.central.name

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}

# Subnet
resource "azurerm_subnet" "central" {
  name                 = "${var.project_name}-subnet"
  resource_group_name  = data.azurerm_resource_group.central.name
  virtual_network_name = azurerm_virtual_network.central.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Central VM module
module "central" {
  source = "../modules/azure-vm"

  name                = "central"
  project_name        = var.project_name
  resource_group_name = data.azurerm_resource_group.central.name
  location            = var.azure_region # Use var to comply with allowed regions policy
  subnet_id           = azurerm_subnet.central.id
  vm_size             = var.central_vm_size
  admin_username      = var.admin_username
  ssh_public_key      = file("${path.module}/../keys/azure-central-key.pub")

  # NSG rules cho Central
  nsg_rules = [
    {
      name                       = "AllowSSH"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefixes    = var.allowed_ssh_cidrs
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowInfluxDB"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "8086"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowChronograf"
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "8888"
      source_address_prefixes    = var.allowed_ssh_cidrs
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowICMP"
      priority                   = 130
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Icmp"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
  ]

  tags = {
    Role = "tick-stack"
  }
}
