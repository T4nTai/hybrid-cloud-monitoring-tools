# =============================================================================
# Module: aws-vm
# Mo ta: Tao mot EC2 instance tren AWS kem Security Group, EIP tuy chon
# =============================================================================

variable "name" {
  description = "Ten Name tag cua instance (vd: central, vm-a)"
  type        = string
}

variable "project_name" {
  description = "Ten du an, dung trong description cua Security Group"
  type        = string
  default     = "hybrid-cloud-monitoring"
}

variable "instance_type" {
  description = "Loai instance EC2"
  type        = string
  default     = "t3.small"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "availability_zone" {
  description = "Availability zone (neu de null se tu chon trong region)"
  type        = string
  default     = null
}

variable "ami_id" {
  description = "AMI ID. Neu null se tim AMI Ubuntu 22.04 moi nhat tu Canonical"
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Subnet ID se deploy instance vao"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID chua subnet"
  type        = string
}

variable "key_name" {
  description = "Ten key pair SSH da tao tren AWS"
  type        = string
}

variable "ssh_user" {
  description = "User SSH de dang nhap (Ubuntu AMI: ubuntu)"
  type        = string
  default     = "ubuntu"
}

variable "root_volume_size_gb" {
  description = "Dung luong root volume (GB)"
  type        = number
  default     = 16
}

variable "root_volume_type" {
  description = "Loai volume (gp3, gp2, io1...)"
  type        = string
  default     = "gp3"
}

variable "associate_public_ip" {
  description = "Co gan public IP khong (can true neu can SSH tu ben ngoai)"
  type        = bool
  default     = true
}

variable "create_elastic_ip" {
  description = "Tao Elastic IP rieng cho instance nay (chi dung cho Central)"
  type        = bool
  default     = false
}

# --- Security Group ---

variable "allowed_ssh_cidrs" {
  description = "Danh sach CIDR duoc phep SSH vao instance"
  type        = list(string)
  default     = []
}

variable "allowed_ingress_rules" {
  description = <<-EOT
    Cac rule inbound them cho Security Group.
    Moi phan tu co dang: { port = 8086, protocol = "tcp", cidr_blocks = ["10.0.0.0/16"], description = "..." }
  EOT
  type = list(object({
    port        = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = []
}

variable "tags" {
  description = "Tags ap dung cho moi tai nguyen trong module"
  type        = map(string)
  default     = {}
}
