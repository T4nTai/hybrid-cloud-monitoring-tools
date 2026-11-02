variable "name" {
  description = "Tên VM"
  type        = string
}

variable "project_name" {
  description = "Tên dự án"
  type        = string
}

variable "resource_group_name" {
  description = "Tên Resource Group"
  type        = string
}

variable "location" {
  description = "Azure location"
  type        = string
}

variable "subnet_id" {
  description = "ID của subnet"
  type        = string
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Username cho SSH"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key content"
  type        = string
}

variable "disk_size_gb" {
  description = "Dung lượng disk (GB)"
  type        = number
  default     = 30
}

variable "nsg_rules" {
  description = "Danh sách NSG rules"
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = optional(string)
    source_address_prefixes    = optional(list(string))
    destination_address_prefix = string
  }))
  default = []
}

variable "tags" {
  description = "Tags cho resources"
  type        = map(string)
  default     = {}
}
