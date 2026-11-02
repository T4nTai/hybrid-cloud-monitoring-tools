output "public_ip" {
  description = "Public IP của VM"
  value       = azurerm_public_ip.vm.ip_address
}

output "private_ip" {
  description = "Private IP của VM"
  value       = azurerm_network_interface.vm.private_ip_address
}

output "vm_id" {
  description = "ID của VM"
  value       = azurerm_linux_virtual_machine.vm.id
}

output "vm_name" {
  description = "Tên VM"
  value       = azurerm_linux_virtual_machine.vm.name
}
