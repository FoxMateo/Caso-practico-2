# Variables generales
variable "location" {
  description = "Región de Azure donde se crearán los recursos"
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Nombre del grupo de recursos"
  type        = string
  default     = "rg-casopractico2"
}

variable "vm_name" {
  description = "Nombre de la máquina virtual"
  type        = string
  default     = "vm-casopractico2"
}

variable "admin_username" {
  description = "Nombre de usuario administrador de la VM"
  type        = string
  default     = "azureuser"
}

variable "acr_name" {
  description = "Nombre del Azure Container Registry (ACR)"
  type        = string
  default     = "acrcasopractico2"
}

variable "aks_name" {
  description = "Nombre del clúster de Azure Kubernetes Service (AKS)"
  type        = string
  default     = "aks-casopractico2"
}

variable "environment" {
  description = "Etiqueta para identificar el entorno"
  type        = string
  default     = "casopractico2"
}

variable "prefix" {
  description = "Prefijo para los nombres de los recursos"
  type        = string
  default     = "cp2"
}