# =============================================================================
# Module: aws-vm
# Tao EC2 instance + Security Group (+ Elastic IP tuy chon)
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws]
    }
  }
}

# --- Locally resolve AMI: Ubuntu 22.04 LTS jammy hvm-ssd gp3 ---
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

locals {
  ami_to_use = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu.id
}

# --- Security Group ---
resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "Security group for ${var.name} (${var.project_name})"
  vpc_id      = var.vpc_id

  # Cho phep ICMP echo de inputs.ping cua Telegraf hoat dong
  ingress {
    description = "Allow ICMP echo request/reply (required for Telegraf inputs.ping)"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = length(var.allowed_ssh_cidrs) > 0 ? var.allowed_ssh_cidrs : ["0.0.0.0/0"]
  }

  # Them rule tuy chon (8086 InfluxDB, 8888 Chronograf, 5201 iperf3, 80 nginx...)
  dynamic "ingress" {
    for_each = var.allowed_ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  # Toan bo outgoing
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-sg"
  })
}

# --- EC2 Instance ---
resource "aws_instance" "this" {
  ami                    = local.ami_to_use
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  key_name               = var.key_name
  availability_zone      = var.availability_zone

  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = var.root_volume_type
    encrypted   = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2
    http_put_response_hop_limit = 1
  }

  tags = merge(var.tags, {
    Name = var.name
    Role = var.name
  })

  lifecycle {
    ignore_changes = [ami]
  }
}

# --- Elastic IP (tuy chon, cho Central can IP on dinh) ---
resource "aws_eip" "this" {
  count = var.create_elastic_ip ? 1 : 0

  domain   = "vpc"
  instance = aws_instance.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-eip"
  })
}
