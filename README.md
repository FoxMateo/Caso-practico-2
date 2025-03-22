# Caso Práctico 2: Automatización en Azure

Este proyecto automatiza el despliegue de infraestructura en Azure utilizando **Terraform** y **Ansible**. Se crea una máquina virtual con un servidor web en contenedor y un clúster de Kubernetes (AKS) para desplegar una aplicación con almacenamiento persistente.

---

## **Requisitos**

- **Azure CLI**: Instalado y configurado.
- **Terraform**: Versión 1.0 o superior.
- **Ansible**: Versión 2.12 o superior.
- **Cuenta de Azure**: Suscripción activa (cambiar el ID en el provider de Terraform).

---

## **Configuración Inicial**

1. **Cambiar la suscripción en Terraform**:
   - Abre el archivo `providers.tf`.
   - Reemplaza el valor de `subscription_id` con el ID de tu suscripción de Azure:
     ```hcl
     provider "azurerm" {
       features {}
       subscription_id = "tu-id-de-suscripción"
     }
     ```

2. **Autenticación en Azure**:
   - Ejecuta `az login` para autenticarte en Azure.

## **Despliegue**

El proyecto esta tanto para desplegar todo con terraform como para ir desplegando parte por parte, dejo todos los comandos para ello

1. **Infraestructura con Terraform**:
   - Inicializa Terraform:
     ```bash
     terraform init
     ```
   - Revisa el plan de despliegue:
     ```bash
     terraform plan
     ```
   - Aplica los cambios:
     ```bash
     terraform apply
     ```
2. **Configuración con Ansible**:
   - Si se depliega de esta manera se debera de crear un host en /ansible y un archivo vars.yaml para las variables del playbook
   - Ejecuta el playbook para configurar la VM:
     ```bash
     ansible-playbook -i inventory vm-playbook.yml
     ```

3. **Despliegue en Kubernetes**:
   - Aplica los manifiestos YAML en AKS:
     ```bash
     kubectl apply -f kubernetes/
     ```

---

## **Problemas Comunes**

- **Límite de IPs públicas**: La cuenta de estudiante solo permite 3 IPs públicas. Si el servicio LoadBalancer de AKS queda en *Pending*, libera la IP de la VM temporalmente.
- **Advertencia de SSH**: Usa `--ssh-common-args='-o StrictHostKeyChecking=no'` en Ansible para evitar confirmaciones manuales.

---

---

## **NOTAS**

**Casi al finalizar terraform saltara un error de que no ha podido crear uno de los servicios de kubernetes, pero si lo ha creado, este error se da por el problema de las ips publicas que solo permiten 3, y uno de los servicios se queda en estado pending**

---