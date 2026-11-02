output "central_public_ip" {
  description = "Public IP của Central VM"
  value       = module.central.public_ip
}

output "central_private_ip" {
  description = "Private IP của Central VM"
  value       = module.central.private_ip
}

output "resource_group_name" {
  description = "Tên Resource Group"
  value       = data.azurerm_resource_group.central.name
}

output "ssh_command" {
  description = "Lệnh SSH vào Central"
  value       = "ssh ${var.admin_username}@${module.central.public_ip}"
}

output "chronograf_url" {
  description = "URL Chronograf dashboard"
  value       = "http://${module.central.public_ip}:8888"
}

output "influxdb_url" {
  description = "URL InfluxDB API"
  value       = "http://${module.central.public_ip}:8086"
}

output "summary" {
  description = "Tóm tắt thông tin Central"
  value       = <<-EOT
    ======================================================
    Azure Central VM — Hybrid Cloud Monitoring
    ======================================================
    Public IP:    ${module.central.public_ip}
    Private IP:   ${module.central.private_ip}
    SSH:          ssh ${var.admin_username}@${module.central.public_ip}
    Chronograf:   http://${module.central.public_ip}:8888
    InfluxDB:     http://${module.central.public_ip}:8086
    
    Next: SSH into Central and run setup-central.sh
    ======================================================
  EOT
}
