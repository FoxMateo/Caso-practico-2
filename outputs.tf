# IP pública de la VM
output "vm_public_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}

# Nombre del ACR
output "acr_name" {
  value = azurerm_container_registry.acr.name
}

# URL del ACR
output "acr_url" {
  value = azurerm_container_registry.acr.login_server
}

# Usuario del ACR
output "acr_username" {
  value = azurerm_container_registry.acr.admin_username
}

# Contraseña del ACR
output "acr_password" {
  value     = azurerm_container_registry.acr.admin_password
  sensitive = true
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "frontend_service_ip" {
  value = kubernetes_service.frontend.status.0.load_balancer.0.ingress.0.ip
}