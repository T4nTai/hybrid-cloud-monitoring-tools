# =============================================================================
# Outputs cua module aws-vm
# =============================================================================

output "instance_id" {
  description = "ID cua EC2 instance"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP cua instance"
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP hien tai cua instance"
  value       = aws_instance.this.public_ip
}

output "elastic_ip" {
  description = "Elastic IP (neu co tao), null neu khong tao"
  value       = var.create_elastic_ip ? aws_eip.this[0].public_ip : null
}

output "security_group_id" {
  description = "ID cua Security Group"
  value       = aws_security_group.this.id
}

output "availability_zone" {
  description = "AZ dang chay"
  value       = aws_instance.this.availability_zone
}

output "ami_id" {
  description = "AMI ID da dung"
  value       = local.ami_to_use
}

output "ssh_command" {
  description = "Lenh SSH de ket noi"
  value       = "ssh ${var.ssh_user}@${var.create_elastic_ip ? aws_eip.this[0].public_ip : aws_instance.this.public_ip}"
}
