terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.singapore, aws.tokyo, aws.useast]
    }
  }
}

# Provider cho VM-B (Singapore)
provider "aws" {
  alias  = "singapore"
  region = var.singapore_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
      Component   = "hybrid-cloud-monitoring-agent"
    }
  }
}

# Provider cho VM-C (Tokyo)
provider "aws" {
  alias  = "tokyo"
  region = var.tokyo_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
      Component   = "hybrid-cloud-monitoring-distance"
    }
  }
}

# Provider cho VM-D (US-East)
provider "aws" {
  alias  = "useast"
  region = var.useast_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
      Component   = "hybrid-cloud-monitoring-distance"
    }
  }
}

# Data sources cho VPC/Subnet mỗi region
data "aws_vpc" "singapore" {
  count    = var.use_default_vpc ? 1 : 0
  default  = true
  provider = aws.singapore
}

data "aws_subnets" "singapore" {
  count    = var.use_default_vpc ? 1 : 0
  provider = aws.singapore
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.singapore[0].id]
  }
}

data "aws_vpc" "tokyo" {
  count    = var.use_default_vpc && var.enable_distance_vms ? 1 : 0
  default  = true
  provider = aws.tokyo
}

data "aws_subnets" "tokyo" {
  count    = var.use_default_vpc && var.enable_distance_vms ? 1 : 0
  provider = aws.tokyo
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.tokyo[0].id]
  }
}

data "aws_vpc" "useast" {
  count    = var.use_default_vpc && var.enable_distance_vms ? 1 : 0
  default  = true
  provider = aws.useast
}

data "aws_subnets" "useast" {
  count    = var.use_default_vpc && var.enable_distance_vms ? 1 : 0
  provider = aws.useast
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.useast[0].id]
  }
}
