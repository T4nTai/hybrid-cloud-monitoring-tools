# =============================================================================
# AWS — Các VM AGENT trong cloud được đo (KHÔNG còn Central ở đây)
#   VM-B : ap-southeast-1 (Singapore) — agent + benchmark peer
#   VM-C : ap-northeast-1 (Tokyo)     — đo khoảng cách (~5300 km)  [optional]
#   VM-D : us-east-1 (Virginia)       — đo khoảng cách (~15400 km) [optional]
# Central (TICK stack) nằm ở Azure — xem ../azure/
# =============================================================================

# --- Key Pairs (mỗi region cần 1 key pair) ---
resource "aws_key_pair" "singapore" {
  count      = var.create_key_pair ? 1 : 0
  provider   = aws.singapore
  key_name   = var.key_name
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

resource "aws_key_pair" "tokyo" {
  count      = var.create_key_pair && var.enable_distance_vms ? 1 : 0
  provider   = aws.tokyo
  key_name   = var.key_name
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

resource "aws_key_pair" "useast" {
  count      = var.create_key_pair && var.enable_distance_vms ? 1 : 0
  provider   = aws.useast
  key_name   = var.key_name
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

locals {
  key_name_effective = var.key_name
  admin_cidr         = length(var.allowed_ssh_cidr) > 0 ? var.allowed_ssh_cidr : ["0.0.0.0/0"]
}

# =============================================================================
# VM-B — AWS ap-southeast-1 (Singapore) — agent + benchmark peer
# Đây là "đối tác" đo hiệu năng với VM-A bên on-premise
# =============================================================================
module "vm_b" {
  source = "../modules/aws-vm"

  providers = {
    aws = aws.singapore
  }

  name                = "vm-b"
  project_name        = var.project_name
  instance_type       = var.vmb_instance_type
  region              = var.singapore_region
  key_name            = local.key_name_effective
  vpc_id              = var.use_default_vpc ? data.aws_vpc.singapore[0].id : var.vpc_id_singapore
  subnet_id           = var.use_default_vpc ? data.aws_subnets.singapore[0].ids[0] : var.subnet_ids_singapore[0]
  root_volume_size_gb = var.root_volume_size_gb

  create_elastic_ip = true # IP tĩnh để on-premise và Central luôn ping/đẩy được
  allowed_ssh_cidrs = local.admin_cidr

  # VM-B KHÔNG mở 8086 (Central ở Azure). Chỉ ICMP inbound (module tự mở) + SSH.
  # iperf3 chỉ cho phép từ subnet WireGuard (VM-A) — không mở ra Internet.
  allowed_ingress_rules = [
    {
      description = "iperf3 from WireGuard peer (VM-A)"
      port        = 5201
      protocol    = "tcp"
      cidr_blocks = ["10.200.200.0/24"]
    },
    {
      description = "iperf3 UDP from WireGuard peer (VM-A)"
      port        = 5201
      protocol    = "udp"
      cidr_blocks = ["10.200.200.0/24"]
    },
    {
      description = "HTTP nginx from WireGuard peer (VM-A) for ab test"
      port        = 80
      protocol    = "tcp"
      cidr_blocks = ["10.200.200.0/24"]
    }
  ]

  tags = {
    Name        = "vm-b"
    Role        = "agent"
    Environment = var.environment
  }

  depends_on = [aws_key_pair.singapore]
}

# =============================================================================
# VM-C — AWS ap-northeast-1 (Tokyo) — đo ảnh hưởng khoảng cách (TN2)
# Bật/tắt bằng biến enable_distance_vms để tiết kiệm chi phí
# =============================================================================
module "vm_c" {
  source = "../modules/aws-vm"

  count = var.enable_distance_vms ? 1 : 0

  providers = {
    aws = aws.tokyo
  }

  name                = "vm-c"
  project_name        = var.project_name
  instance_type       = var.distance_instance_type
  region              = var.tokyo_region
  key_name            = local.key_name_effective
  vpc_id              = var.use_default_vpc ? data.aws_vpc.tokyo[0].id : var.vpc_id_tokyo
  subnet_id           = var.use_default_vpc ? data.aws_subnets.tokyo[0].ids[0] : var.subnet_ids_tokyo[0]
  root_volume_size_gb = var.root_volume_size_gb

  create_elastic_ip     = true
  allowed_ssh_cidrs     = local.admin_cidr
  allowed_ingress_rules = []

  tags = {
    Name        = "vm-c"
    Role        = "distance-probe"
    Environment = var.environment
  }

  depends_on = [aws_key_pair.tokyo]
}

# =============================================================================
# VM-D — AWS us-east-1 (Virginia) — đo ảnh hưởng khoảng cách xa (TN2)
# =============================================================================
module "vm_d" {
  source = "../modules/aws-vm"

  count = var.enable_distance_vms ? 1 : 0

  providers = {
    aws = aws.useast
  }

  name                = "vm-d"
  project_name        = var.project_name
  instance_type       = var.distance_instance_type
  region              = var.useast_region
  key_name            = local.key_name_effective
  vpc_id              = var.use_default_vpc ? data.aws_vpc.useast[0].id : var.vpc_id_useast
  subnet_id           = var.use_default_vpc ? data.aws_subnets.useast[0].ids[0] : var.subnet_ids_useast[0]
  root_volume_size_gb = var.root_volume_size_gb

  create_elastic_ip     = true
  allowed_ssh_cidrs     = local.admin_cidr
  allowed_ingress_rules = []

  tags = {
    Name        = "vm-d"
    Role        = "distance-probe"
    Environment = var.environment
  }

  depends_on = [aws_key_pair.useast]
}

# =============================================================================
# VM-E — AWS ap-southeast-2 (Sydney) — probe khoảng cách (~7000 km tới HK)
# =============================================================================
resource "aws_key_pair" "sydney" {
  count      = var.create_key_pair && var.enable_distance_vms ? 1 : 0
  provider   = aws.sydney
  key_name   = var.key_name
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

module "vm_e" {
  source = "../modules/aws-vm"
  count  = var.enable_distance_vms ? 1 : 0

  providers = {
    aws = aws.sydney
  }

  name                = "vm-e"
  project_name        = var.project_name
  instance_type       = var.distance_instance_type
  region              = var.sydney_region
  key_name            = local.key_name_effective
  vpc_id              = data.aws_vpc.sydney[0].id
  subnet_id           = data.aws_subnets.sydney[0].ids[0]
  root_volume_size_gb = var.root_volume_size_gb

  create_elastic_ip     = true
  allowed_ssh_cidrs     = local.admin_cidr
  allowed_ingress_rules = []

  tags = {
    Name        = "vm-e"
    Role        = "distance-probe"
    Environment = var.environment
  }

  depends_on = [aws_key_pair.sydney]
}

# =============================================================================
# VM-F — AWS eu-central-1 (Frankfurt) — probe khoảng cách (~9300 km tới HK)
# =============================================================================
resource "aws_key_pair" "frankfurt" {
  count      = var.create_key_pair && var.enable_distance_vms ? 1 : 0
  provider   = aws.frankfurt
  key_name   = var.key_name
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

module "vm_f" {
  source = "../modules/aws-vm"
  count  = var.enable_distance_vms ? 1 : 0

  providers = {
    aws = aws.frankfurt
  }

  name                = "vm-f"
  project_name        = var.project_name
  instance_type       = var.distance_instance_type
  region              = var.frankfurt_region
  key_name            = local.key_name_effective
  vpc_id              = data.aws_vpc.frankfurt[0].id
  subnet_id           = data.aws_subnets.frankfurt[0].ids[0]
  root_volume_size_gb = var.root_volume_size_gb

  create_elastic_ip     = true
  allowed_ssh_cidrs     = local.admin_cidr
  allowed_ingress_rules = []

  tags = {
    Name        = "vm-f"
    Role        = "distance-probe"
    Environment = var.environment
  }

  depends_on = [aws_key_pair.frankfurt]
}
