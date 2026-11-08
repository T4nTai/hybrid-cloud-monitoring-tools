# =============================================================================
# Outputs — Biến được Telegraf/Script tham chiếu sau này
# Central nằm ở Azure (xem ../azure/)
# =============================================================================

# --- VM-B (Singapore) ---
output "vmb_public_ip" {
  description = "Public IP/EIP của VM-B (Singapore)"
  value       = module.vm_b.elastic_ip != null ? module.vm_b.elastic_ip : module.vm_b.public_ip
}

output "vmb_private_ip" {
  description = "Private IP của VM-B"
  value       = module.vm_b.private_ip
}

output "vmb_instance_id" {
  description = "EC2 Instance ID của VM-B"
  value       = module.vm_b.instance_id
}

output "vmb_ssh_command" {
  description = "Lệnh SSH vào VM-B"
  value       = module.vm_b.ssh_command
}

# --- VM-C (Tokyo) ---
output "vmc_public_ip" {
  description = "Public IP của VM-C (Tokyo), null nếu không tạo"
  value       = var.enable_distance_vms ? (module.vm_c[0].elastic_ip != null ? module.vm_c[0].elastic_ip : module.vm_c[0].public_ip) : null
}

output "vmc_private_ip" {
  description = "Private IP của VM-C"
  value       = var.enable_distance_vms ? module.vm_c[0].private_ip : null
}

output "vmc_ssh_command" {
  description = "Lệnh SSH vào VM-C"
  value       = var.enable_distance_vms ? module.vm_c[0].ssh_command : null
}

# --- VM-D (US-East) ---
output "vmd_public_ip" {
  description = "Public IP của VM-D (US-East), null nếu không tạo"
  value       = var.enable_distance_vms ? (module.vm_d[0].elastic_ip != null ? module.vm_d[0].elastic_ip : module.vm_d[0].public_ip) : null
}

output "vmd_private_ip" {
  description = "Private IP của VM-D"
  value       = var.enable_distance_vms ? module.vm_d[0].private_ip : null
}

output "vmd_ssh_command" {
  description = "Lệnh SSH vào VM-D"
  value       = var.enable_distance_vms ? module.vm_d[0].ssh_command : null
}

# --- VM-E (Sydney) / VM-F (Frankfurt) ---
output "vme_public_ip" {
  description = "Public IP của VM-E (Sydney), null nếu không tạo"
  value       = var.enable_distance_vms ? module.vm_e[0].elastic_ip : null
}
output "vmf_public_ip" {
  description = "Public IP của VM-F (Frankfurt), null nếu không tạo"
  value       = var.enable_distance_vms ? module.vm_f[0].elastic_ip : null
}

# --- Summary ---
output "summary" {
  description = "Tóm tắt thông tin các VM"
  value       = <<-EOT
    ======================================================
    AWS VMs (Agent nodes - Central đã chuyển sang Azure)
    ======================================================
    VM-B (Singapore):  ${module.vm_b.elastic_ip != null ? module.vm_b.elastic_ip : module.vm_b.public_ip}
    VM-C (Tokyo):      ${var.enable_distance_vms ? (module.vm_c[0].elastic_ip != null ? module.vm_c[0].elastic_ip : module.vm_c[0].public_ip) : "DISABLED"}
    VM-D (US-East):    ${var.enable_distance_vms ? (module.vm_d[0].elastic_ip != null ? module.vm_d[0].elastic_ip : module.vm_d[0].public_ip) : "DISABLED"}
    VM-E (Sydney):     ${var.enable_distance_vms ? (module.vm_e[0].elastic_ip != null ? module.vm_e[0].elastic_ip : module.vm_e[0].public_ip) : "DISABLED"}
    VM-F (Frankfurt):  ${var.enable_distance_vms ? (module.vm_f[0].elastic_ip != null ? module.vm_f[0].elastic_ip : module.vm_f[0].public_ip) : "DISABLED"}

    SSH Commands:
    - VM-B: ${module.vm_b.ssh_command}
    - VM-C: ${var.enable_distance_vms ? module.vm_c[0].ssh_command : "N/A"}
    - VM-D: ${var.enable_distance_vms ? module.vm_d[0].ssh_command : "N/A"}
    - VM-E: ${var.enable_distance_vms ? module.vm_e[0].ssh_command : "N/A"}
    - VM-F: ${var.enable_distance_vms ? module.vm_f[0].ssh_command : "N/A"}

    NOTE: Central (InfluxDB + Chronograf) nằm ở Azure.
    Xem terraform/azure/ để triển khai Central.
    ======================================================
  EOT
}
