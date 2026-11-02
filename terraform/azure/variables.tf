variable "project_name" {
  description = "Tên dự án"
  type        = string
  default     = "hybrid-cloud-monitoring"
}

variable "environment" {
  description = "Môi trường triển khai"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Chủ sở hữu tài nguyên"
  type        = string
  default     = "group-n531"
}

variable "azure_region" {
  description = "Azure region cho Central VM"
  type        = string
  default     = "southeastasia"
}

variable "central_vm_size" {
  description = "Azure VM size cho Central"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Username cho SSH"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Đường dẫn tới SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "allowed_ssh_cidrs" {
  description = "CIDR được phép SSH vào Central"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
