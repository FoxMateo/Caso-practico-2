# Grupo de recursos
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-${var.resource_group_name}"
  location = var.location
  tags = {
    environment = var.environment
  }
}

# Generar un par de claves SSH
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Guardar la clave privada en un archivo local
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/private_key.pem"
  file_permission = "0600"
}

# Crear una red
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = {
    environment = var.environment
  }
}

# Crear una subred
resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Crear una IP pública
resource "azurerm_public_ip" "public_ip" {
  name                = "${var.prefix}-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = {
    environment = var.environment
  }
}

# Crear un grupo de seguridad de red
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = {
    environment = var.environment
  }

  # Regla para permitir SSH
  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Regla para permitir HTTP
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Crear una interfaz de red (NIC)
resource "azurerm_network_interface" "nic" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = {
    environment = var.environment
  }

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# Asociar el NSG a la NIC
resource "azurerm_network_interface_security_group_association" "nsg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Crear la máquina virtual Linux
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.prefix}-${var.vm_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.admin_username
  tags = {
    environment = var.environment
  }

  # Usar la clave pública generada
  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Crear el Azure Container Registry (ACR)
resource "azurerm_container_registry" "acr" {
  name                = "${var.prefix}${var.acr_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
  tags = {
    environment = var.environment
  }
}

# Crear el clúster de Azure Kubernetes Service (AKS)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.prefix}-${var.aks_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${var.prefix}-aks"
  tags = {
    environment = var.environment
  }

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }
}

# Asignar permisos de ACRPull al clúster de AKS
resource "azurerm_role_assignment" "acr_pull" {
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}

# Subida de imagen a registry
resource "null_resource" "push_nginx_to_acr" {
  depends_on = [azurerm_container_registry.acr]

  # Para ejecutar comando en local
  provisioner "local-exec" {
    command = <<EOT
      # Login en ACR
      az acr login --name ${azurerm_container_registry.acr.name}

      # Pull y Push de nginx:stable-otel
      docker pull docker.io/nginx:stable-otel
      docker tag docker.io/nginx:stable-otel ${azurerm_container_registry.acr.login_server}/nginx:stable-otel
      docker push ${azurerm_container_registry.acr.login_server}/nginx:stable-otel

      # Pull y Push de redis:alpine3.21
      docker pull docker.io/redis:alpine3.21
      docker tag docker.io/redis:alpine3.21 ${azurerm_container_registry.acr.login_server}/redis:alpine3.21
      docker push ${azurerm_container_registry.acr.login_server}/redis:alpine3.21

      # Pull y Push de example-voting-app-vote:latest
      docker pull docker.io/docker/example-voting-app-vote:latest
      docker tag docker.io/docker/example-voting-app-vote:latest ${azurerm_container_registry.acr.login_server}/azure-vote-front:v2
      docker push ${azurerm_container_registry.acr.login_server}/azure-vote-front:v2
    EOT
  }
}

# Generar el archivo de inventario de Ansible
resource "local_file" "ansible_host" {
  filename = "ansible/host"
  content  = <<EOT
[vm]
${azurerm_public_ip.public_ip.ip_address} ansible_user=azureuser ansible_ssh_private_key_file=private_key.pem

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOT

  depends_on = [azurerm_linux_virtual_machine.vm]
}

# Generar el archivo de variables para Ansible
resource "local_file" "ansible_vars" {
  filename = "ansible/vars.yml"
  content  = <<EOT
acr_url: ${azurerm_container_registry.acr.login_server}
image_name: "nginx"
image_tag: "stable-otel"
acr_username: ${azurerm_container_registry.acr.admin_username}
acr_password: ${azurerm_container_registry.acr.admin_password}
vm_public_ip: ${azurerm_public_ip.public_ip.ip_address}
EOT

  depends_on = [
    azurerm_container_registry.acr,
    azurerm_public_ip.public_ip
  ]
}

# Recurso para ejecutar el playbook de Ansible
resource "null_resource" "run_ansible_playbook" {
  depends_on = [
    local_file.ansible_host,
    local_file.ansible_vars,
    azurerm_linux_virtual_machine.vm
  ]

  provisioner "local-exec" {
    command = <<EOT
      sleep 60 && ansible-playbook -i ansible/host ansible/vm-playbook.yml --ssh-common-args='-o StrictHostKeyChecking=no'
    EOT
  }
}

# Crear un Namespace en Kubernetes
resource "kubernetes_namespace" "unir_practica2" {
  metadata {
    name = "unir-practica2"
  }
}

# Crear un PersistentVolume (PV) para Redis
resource "kubernetes_persistent_volume" "redis_pv" {
  metadata {
    name = "redis-pv"
  }
  spec {
    capacity = {
      storage = "1Gi"
    }
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "manual"
    persistent_volume_source {
      host_path {
        path = "/mnt/data"
      }
    }
  }
}

# Crear un PersistentVolumeClaim (PVC) para Redis
resource "kubernetes_persistent_volume_claim" "redis_pvc" {
  metadata {
    name = "redis-pvc"
    namespace = kubernetes_namespace.unir_practica2.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
    storage_class_name = "manual"
    volume_name = kubernetes_persistent_volume.redis_pv.metadata[0].name
  }
}

# Crear un Deployment para Redis
resource "kubernetes_deployment" "redis" {
  metadata {
    name = "redis"
    namespace = kubernetes_namespace.unir_practica2.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "redis"
      }
    }
    template {
      metadata {
        labels = {
          app = "redis"
        }
      }
      spec {
        container {
          name = "redis"
          image = "${azurerm_container_registry.acr.login_server}/redis:alpine3.21"
          port {
            container_port = 6379
          }
          volume_mount {
            name = "redis-storage"
            mount_path = "/data"
          }
        }
        volume {
          name = "redis-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.redis_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

# Crear un Service para Redis
resource "kubernetes_service" "redis" {
  metadata {
    name = "redis"
    namespace = kubernetes_namespace.unir_practica2.metadata[0].name
  }
  spec {
    selector = {
      app = "redis"
    }
    port {
      port = 6379
      target_port = 6379
    }
    type = "LoadBalancer"
  }
}

resource "kubernetes_deployment" "frontend" {
  metadata {
    name = "frontend"
    namespace = kubernetes_namespace.unir_practica2.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "frontend"
      }
    }
    template {
      metadata {
        labels = {
          app = "frontend"
        }
      }
      spec {
        container {
          name = "frontend"
          image = "${azurerm_container_registry.acr.login_server}/azure-vote-front:v2"
          port {
            container_port = 8081
          }
          env {
            name = "REDIS_HOST"
            value = "redis"
          }
          env {
            name = "REDIS_PORT"
            value = "6379"
          }
        }
      }
    }
  }
}

# Crear un Service para el Frontend (LoadBalancer)
resource "kubernetes_service" "frontend" {
  metadata {
    name = "frontend"
    namespace = kubernetes_namespace.unir_practica2.metadata[0].name
  }
  spec {
    selector = {
      app = "frontend"
    }
    port {
      port = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}
