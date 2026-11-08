# =============================================================================
# Biến cho AWS Agent VMs (Central đã chuyển sang Azure)
# =============================================================================

# --- Regions ---
variable "singapore_region" {
  description = "AWS region cho VM-B (Singapore)"
  type        = string
  default     = "ap-southeast-1"
}

variable "tokyo_region" {
  description = "AWS region cho VM-C (Tokyo, đo khoảng cách)"
  type        = string
  default     = "ap-northeast-1"
}

variable "useast_region" {
  description = "AWS region cho VM-D (US-East, đo khoảng cách xa)"
  type        = string
  default     = "us-east-1"
}

variable "sydney_region" {
  description = "AWS region cho VM-E (Sydney, đo khoảng cách trung)"
  type        = string
  default     = "ap-southeast-2"
}

variable "frankfurt_region" {
  description = "AWS region cho VM-F (Frankfurt, đo khoảng cách trung-xa)"
  type        = string
  default     = "eu-central-1"
}

# --- Project metadata ---
variable "project_name" {
  description = "Tên dự án"
  type        = string
  default     = "hybrid-cloud-monitoring"
}

variable "environment" {
  description = "Môi trường triển khai"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment phải là dev, staging hoặc prod."
  }
}

variable "owner" {
  description = "Chủ sở hữu tài nguyên, dùng cho tag billing"
  type        = string
  default     = "group-n531"
}

# --- SSH Key ---
variable "key_name" {
  description = "Tên AWS Key Pair dùng cho SSH"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Đường dẫn file SSH public key (khi tạo Key Pair mới)"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "create_key_pair" {
  description = "Tự tạo Key Pair từ ssh_public_key_path hay dùng Key Pair sẵn có"
  type        = bool
  default     = true
}

variable "allowed_ssh_cidr" {
  description = "CIDR được phép SSH (VD: [\"203.0.113.10/32\"]). KHÔNG để 0.0.0.0/0."
  type        = list(string)
  default     = []
}

# --- VPC (dùng default VPC cho đơn giản) ---
variable "use_default_vpc" {
  description = "Dùng default VPC của mỗi region hay VPC riêng"
  type        = bool
  default     = true
}

variable "vpc_id_singapore" {
  description = "VPC ID cho Singapore (khi use_default_vpc = false)"
  type        = string
  default     = ""
}

variable "subnet_ids_singapore" {
  description = "Danh sách subnet ID cho Singapore"
  type        = list(string)
  default     = []
}

variable "vpc_id_tokyo" {
  description = "VPC ID cho Tokyo (khi use_default_vpc = false)"
  type        = string
  default     = ""
}

variable "subnet_ids_tokyo" {
  description = "Danh sách subnet ID cho Tokyo"
  type        = list(string)
  default     = []
}

variable "vpc_id_useast" {
  description = "VPC ID cho US-East (khi use_default_vpc = false)"
  type        = string
  default     = ""
}

variable "subnet_ids_useast" {
  description = "Danh sách subnet ID cho US-East"
  type        = list(string)
  default     = []
}

# --- Instance types ---
variable "vmb_instance_type" {
  description = "Instance type cho VM-B (agent + benchmark)"
  type        = string
  default     = "t3.small"
}

variable "distance_instance_type" {
  description = "Instance type cho VM-C và VM-D (đo khoảng cách)"
  type        = string
  default     = "t3.micro" # Chỉ chạy Telegraf ping, không cần lớn
}

variable "root_volume_size_gb" {
  description = "Dung lượng root volume cho mỗi instance (GB)"
  type        = number
  default     = 16
}

# --- Features ---
variable "enable_distance_vms" {
  description = "Tạo VM-C (Tokyo) và VM-D (US-East) để đo ảnh hưởng khoảng cách (TN2)"
  type        = bool
  default     = false # Chỉ bật khi chạy TN2 để tiết kiệm
}
