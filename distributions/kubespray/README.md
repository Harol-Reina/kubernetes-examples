# Kubespray - Despliegue de Kubernetes con Ansible

Kubespray es una herramienta que utiliza Ansible para desplegar y gestionar clusters de Kubernetes de forma automatizada en múltiples proveedores de infraestructura.

## 📋 Descripción

**Kubespray** es una colección de playbooks de Ansible que automatiza el despliegue, configuración y mantenimiento de clusters de Kubernetes. Es ideal para despliegues de producción en bare metal, VMs, y proveedores de nube.

### ✨ Características Principales

- **🔧 Automatización completa**: Despliegue sin intervención manual
- **🏗️ Multi-proveedor**: AWS, GCE, Azure, OpenStack, vSphere, bare metal
- **🔒 Configuración de seguridad**: RBAC, Network Policies, TLS automático
- **📈 Escalabilidad**: Soporte para clusters de miles de nodos
- **🔄 Actualizaciones**: Upgrades automáticos de Kubernetes
- **🌐 Múltiples CNI**: Calico, Flannel, Weave, Cilium, Kube-router
- **🛡️ Alta disponibilidad**: Control plane distribuido
- **📊 Monitoreo integrado**: Prometheus, Grafana opcionales

## � Prerrequisitos del Sistema

### ⚠️ Configuración Inicial del Servidor
Kubespray se ejecuta desde un **servidor de control** (puede ser tu laptop o un servidor dedicado) y despliega Kubernetes en **nodos objetivo**. Para servidores Debian con instalación básica:

#### 🔧 Configurar sudo en Debian
Si tu servidor Debian tiene solo SSH y no tiene `sudo` instalado:
```bash
# Conectarse como root
su -

# Instalar sudo
apt update && apt install sudo

# Agregar usuario al grupo sudo (reemplaza 'usuario' con tu nombre de usuario)
usermod -aG sudo usuario

# Verificar configuración
groups usuario
```
📚 **Guía completa**: [Configuración de sudo en Debian](https://harol-reina.github.io/blog/post-3/)

#### � Configurar Repositorios de Debian
Después de configurar sudo, es importante configurar los repositorios para tener acceso completo a los paquetes:
```bash
# Eliminar el repositorio CD-ROM del sistema
sudo sed -i '/cdrom:/s/^/#/' /etc/apt/sources.list

# Habilitar las secciones non-free y contrib automáticamente
sudo apt-add-repository "deb http://deb.debian.org/debian/ $(lsb_release -sc) main contrib non-free non-free-firmware"

# Actualizar los repositorios
sudo apt update
```

#### �🔑 Configurar Claves SSH
Para conectarse a los nodos sin contraseña, necesitas configurar claves SSH:
```bash
# Generar clave SSH (si no tienes una)
ssh-keygen -t rsa -b 4096 -C "tu-email@ejemplo.com"

# Copiar clave pública a cada nodo objetivo
ssh-copy-id usuario@ip-del-nodo

# Verificar conexión sin contraseña
ssh usuario@ip-del-nodo
```
📚 **Guía completa**: [Configuración de claves SSH](https://harol-reina.github.io/blog/post-5/)

#### 🖥️ Requisitos de los Nodos Objetivo
Los nodos donde se instalará Kubernetes deben tener:
```bash
# En cada nodo objetivo (masters y workers):
# 1. Sistema operativo soportado (Ubuntu 20.04+, Debian 11+, CentOS 8+)
# 2. Usuario con privilegios sudo
# 3. Acceso SSH configurado
# 4. Al menos 2GB RAM (4GB+ recomendado para masters)
# 5. Al menos 2 CPU cores
# 6. 20GB+ de espacio en disco

# Verificar recursos en cada nodo:
free -h  # Memoria RAM
nproc    # CPUs
df -h    # Espacio en disco
```

### 🐳 Instalar Docker (Para método recomendado)
```bash
# Instalar Docker en el servidor de control
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Agregar usuario al grupo docker
sudo usermod -aG docker $USER

# Reiniciar sesión o ejecutar
newgrp docker

# Verificar instalación
docker --version
```

### ✅ Verificación de Prerrequisitos
Antes de continuar, asegúrate de tener:
- [ ] `sudo` configurado en el servidor de control
- [ ] Repositorios de Debian configurados (non-free y contrib habilitados)
- [ ] Docker instalado en el servidor de control
- [ ] Claves SSH configuradas para acceso sin contraseña a todos los nodos
- [ ] Conectividad de red entre el servidor de control y los nodos objetivo

## �🚀 Instalación Rápida

### Método Recomendado: Docker (Sin dependencias locales)
```bash
# 1. Clonar Kubespray en el servidor de control
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray

# 2. Configurar inventario con las IPs de tus nodos
# IMPORTANTE: Edita inventory/sample/inventory.ini con las IPs reales de tus nodos
# Ejemplo:
# [kube_control_plane]
# worker ansible_host=192.168.1.160
#
# [etcd:children]
# kube_control_plane
#
# [kube_node]
# worker ansible_host=192.168.1.150
#
# [all:vars]
# ansible_user=<usuario creado>
# ansible_become=true
# ansible_become_user=root
# ansible_become_pass=<pasword de root (Sistemas Debian)>

nano inventory/sample/inventory.ini

# 3. Ejecutar contenedor con Kubespray y dependencias incluidas
docker run --rm -it --mount type=bind,source="$(pwd)"/inventory/sample,dst=/inventory \
  --mount type=bind,source="${HOME}"/.ssh/id_rsa,dst=/root/.ssh/id_rsa \
  quay.io/kubespray/kubespray:v2.28.0 bash

# 4. Dentro del contenedor, verificar conectividad y ejecutar el playbook:
# Verificar acceso SSH a todos los nodos
ansible all -i /inventory/inventory.ini --private-key /root/.ssh/id_rsa -m ping

# Desplegar Kubernetes
ansible-playbook -i /inventory/inventory.ini --private-key /root/.ssh/id_rsa cluster.yml
```

### Método Tradicional: Instalación Local
```bash
# 1. Instalar Ansible y dependencias
sudo apt update && sudo apt install -y python3-pip
pip3 install ansible netaddr

# 2. Clonar Kubespray
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray

# 3. Instalar dependencias de Python
sudo pip3 install -r requirements.txt

# 4. Configurar inventario
cp -rfp inventory/sample inventory/mycluster

# 5. Configurar IPs de los nodos (EDITAR CON TUS IPs)
declare -a IPS=(10.10.1.3 10.10.1.4 10.10.1.5)
CONFIG_FILE=inventory/mycluster/hosts.yaml python3 contrib/inventory_builder/inventory.py ${IPS[@]}

# 6. Desplegar cluster
ansible-playbook -i inventory/mycluster/hosts.yaml --become --become-user=root cluster.yml
```

## 📁 Estructura del Directorio

```
kubespray/
├── README.md                    # Este archivo
├── specific-configs/            # Configuraciones específicas de Kubespray
│   ├── inventory/              # Inventarios de Ansible
│   ├── group_vars/             # Variables por grupos
│   ├── custom-addons/          # Addons personalizados
│   └── network-plugins/        # Configuraciones de CNI
└── automation/                 # Scripts de automatización
    ├── deploy-cluster.sh       # Script de despliegue completo
    ├── upgrade-cluster.sh      # Script de actualización
    ├── scale-cluster.sh        # Script de escalado
    └── backup-cluster.sh       # Script de backup
```

## 🎯 Casos de Uso

### 🏢 Producción Enterprise
- **Clusters grandes**: 100+ nodos con alta disponibilidad
- **Múltiples regiones**: Despliegue en diferentes zonas geográficas
- **Compliance**: Configuraciones que cumplen estándares de seguridad
- **Disaster recovery**: Backups automáticos y procedimientos de recuperación

### 🔬 Laboratorios y Testing
- **Clusters de prueba**: Despliegue rápido para testing
- **CI/CD**: Integración con pipelines de desarrollo
- **Diferentes versiones**: Testing de upgrades de Kubernetes
- **Network testing**: Pruebas con diferentes CNI plugins

### 🌐 Multi-Cloud
- **Hybrid cloud**: Clusters distribuidos entre proveedores
- **Edge computing**: Despliegue en ubicaciones remotas
- **On-premises**: Instalación en datacenter propio
- **Cloud migration**: Migración entre proveedores

## ⚙️ Configuraciones Disponibles

### 🔧 specific-configs/
Configuraciones específicas que aprovechan las capacidades únicas de Kubespray:

#### Inventarios de Ansible
- **Inventory templates**: Para diferentes topologías
- **Group variables**: Configuración por roles de nodos
- **Host variables**: Configuración específica por servidor

#### Custom Addons
- **Helm charts**: Instalación automática de aplicaciones
- **Operators**: Despliegue de operadores personalizados
- **Monitoring stack**: Prometheus, Grafana, AlertManager

#### Network Plugins
- **Calico**: Para micro-segmentación avanzada
- **Flannel**: Para simplicidad y performance
- **Cilium**: Para observabilidad y seguridad eBPF

### 🤖 automation/
Scripts que automatizan operaciones comunes:

#### Despliegue y Gestión
- **Deploy completo**: Desde bare metal hasta cluster funcional
- **Upgrade automático**: Actualización de versiones sin downtime
- **Scaling**: Adición/remoción de nodos automática

#### Mantenimiento
- **Backup programado**: Backup de etcd y configuraciones
- **Health checks**: Monitoreo automático del cluster
- **Certificate renewal**: Renovación automática de certificados

## 🛠️ Comandos Esenciales

> **💡 Tip**: En GitHub, cada bloque de código tiene un botón de copia (📋) en la esquina superior derecha. ¡Úsalo para copiar comandos fácilmente!

### 🐳 Comandos Docker (Recomendado)

#### Configuración con Docker
```bash
# 1. Descargar imagen de Kubespray
docker pull quay.io/kubespray/kubespray:v2.28.0

# 2. Ejecutar contenedor interactivo con montajes
docker run --rm -it \
  --mount type=bind,source="$(pwd)"/inventory/sample,dst=/inventory \
  --mount type=bind,source="${HOME}"/.ssh/id_rsa,dst=/root/.ssh/id_rsa \
  quay.io/kubespray/kubespray:v2.28.0 bash

# 3. Dentro del contenedor: Desplegar cluster
ansible-playbook -i /inventory/inventory.ini --private-key /root/.ssh/id_rsa cluster.yml
```

#### Operaciones del Cluster con Docker
```bash
# Actualizar cluster existente
docker run --rm -it \
  --mount type=bind,source="$(pwd)"/inventory/sample,dst=/inventory \
  --mount type=bind,source="${HOME}"/.ssh/id_rsa,dst=/root/.ssh/id_rsa \
  quay.io/kubespray/kubespray:v2.28.0 bash -c \
  "ansible-playbook -i /inventory/inventory.ini --private-key /root/.ssh/id_rsa upgrade-cluster.yml"

# Escalar cluster (añadir nodos)
docker run --rm -it \
  --mount type=bind,source="$(pwd)"/inventory/sample,dst=/inventory \
  --mount type=bind,source="${HOME}"/.ssh/id_rsa,dst=/root/.ssh/id_rsa \
  quay.io/kubespray/kubespray:v2.28.0 bash -c \
  "ansible-playbook -i /inventory/inventory.ini --private-key /root/.ssh/id_rsa scale.yml"
```

### ⚡ Comandos Tradicionales (Ansible Local)

#### Configuración rápida
```bash
# Instalación completa de Ansible + dependencias
curl -fsSL https://raw.githubusercontent.com/kubernetes-sigs/kubespray/master/requirements.txt | sudo pip3 install -r /dev/stdin && sudo apt update && sudo apt install -y python3-pip ansible

# Configuración rápida de inventario (EDITAR IPs)
declare -a IPS=(10.10.1.3 10.10.1.4 10.10.1.5) && CONFIG_FILE=inventory/mycluster/hosts.yaml python3 contrib/inventory_builder/inventory.py ${IPS[@]}
```

#### Despliegue Inicial
```bash
# 1. Preparar inventario
./automation/prepare-inventory.sh

# 2. Desplegar cluster
./automation/deploy-cluster.sh production

# 3. Verificar instalación
kubectl get nodes
kubectl get pods --all-namespaces
```

### Operaciones del Cluster
```bash
# Añadir nodos worker
./automation/scale-cluster.sh add-workers 2

# Actualizar Kubernetes
./automation/upgrade-cluster.sh v1.28.0

# Backup del cluster
./automation/backup-cluster.sh
```

### Gestión de Addons
```bash
# Instalar addon personalizado
ansible-playbook -i inventory/mycluster/hosts.yaml specific-configs/custom-addons/monitoring.yml

# Configurar network policy
kubectl apply -f specific-configs/network-plugins/calico-policies.yaml
```

## 📊 Monitoreo y Troubleshooting

### Health Checks con Docker
```bash
# Verificar estado del cluster usando Docker
docker run --rm -it \
  --mount type=bind,source="$(pwd)"/inventory/sample,dst=/inventory \
  --mount type=bind,source="${HOME}"/.ssh/id_rsa,dst=/root/.ssh/id_rsa \
  quay.io/kubespray/kubespray:v2.28.0 bash -c \
  "ansible-playbook -i /inventory/inventory.ini --private-key /root/.ssh/id_rsa cluster.yml --tags=health-check"

# Verificar conectividad de red
docker run --rm -it \
  --mount type=bind,source="$(pwd)"/inventory/sample,dst=/inventory \
  --mount type=bind,source="${HOME}"/.ssh/id_rsa,dst=/root/.ssh/id_rsa \
  quay.io/kubespray/kubespray:v2.28.0 bash -c \
  "ansible all -i /inventory/inventory.ini --private-key /root/.ssh/id_rsa -m ping"
```

### Logs y Debugging con Docker
```bash
# Logs de kubelet en todos los nodos
docker run --rm -it \
  --mount type=bind,source="$(pwd)"/inventory/sample,dst=/inventory \
  --mount type=bind,source="${HOME}"/.ssh/id_rsa,dst=/root/.ssh/id_rsa \
  quay.io/kubespray/kubespray:v2.28.0 bash -c \
  "ansible all -i /inventory/inventory.ini --private-key /root/.ssh/id_rsa -m shell -a 'journalctl -u kubelet --no-pager -l'"

# Estado de servicios críticos
docker run --rm -it \
  --mount type=bind,source="$(pwd)"/inventory/sample,dst=/inventory \
  --mount type=bind,source="${HOME}"/.ssh/id_rsa,dst=/root/.ssh/id_rsa \
  quay.io/kubespray/kubespray:v2.28.0 bash -c \
  "ansible masters -i /inventory/inventory.ini --private-key /root/.ssh/id_rsa -m shell -a 'systemctl status kubelet kube-apiserver'"
```

### Health Checks Tradicionales
```bash
# Verificar estado del cluster
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml --tags=health-check

# Verificar conectividad de red
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml --tags=network-test
```

### Logs y Debugging Tradicionales
```bash
# Logs de kubelet en todos los nodos
ansible all -i inventory/mycluster/hosts.yaml -m shell -a "journalctl -u kubelet --no-pager -l"

# Estado de servicios críticos
ansible masters -i inventory/mycluster/hosts.yaml -m shell -a "systemctl status kubelet kube-apiserver"
```

## 🔐 Configuraciones de Seguridad

### RBAC y Security Policies
- **Pod Security Standards**: Configuración automática de políticas de seguridad
- **Network Policies**: Micro-segmentación por defecto
- **Certificate management**: Rotación automática de certificados
- **Secrets encryption**: Encriptación de secrets en etcd

### Hardening del Cluster
- **CIS Benchmarks**: Configuraciones que siguen estándares CIS
- **AppArmor/SELinux**: Políticas de seguridad a nivel de OS
- **Firewall rules**: Configuración automática de iptables
- **Audit logging**: Logs de auditoría de API server

## 📈 Escalabilidad y Performance

### Configuraciones de Performance
```yaml
# group_vars/k8s_cluster/k8s-cluster.yml
kube_apiserver_request_timeout: "300s"
etcd_snapshot_count: 10000
kube_controller_node_monitor_grace_period: 40s
kube_controller_pod_eviction_timeout: 5m
```

### Límites de Recursos
```yaml
# group_vars/all/docker.yml
docker_daemon_graph: "/var/lib/docker"
docker_log_driver: "json-file"
docker_log_opts:
  max-size: "50m"
  max-file: "5"
```

## 🤝 Integración con Herramientas

### CI/CD Integration
- **GitLab CI**: Pipelines para despliegue automático
- **Jenkins**: Jobs para gestión de clusters
- **ArgoCD**: GitOps para aplicaciones

### Infrastructure as Code
- **Terraform**: Provisioning de infraestructura
- **Pulumi**: Despliegue declarativo
- **Crossplane**: Gestión de recursos cloud

## 📚 Recursos y Referencias

- [Documentación Oficial de Kubespray](https://kubespray.io/)
- [Repositorio GitHub](https://github.com/kubernetes-sigs/kubespray)
- [Guías de Configuración](https://kubespray.io/#/docs/getting-started)
- [Best Practices](https://kubespray.io/#/docs/kubernetes-reliability)
- [Troubleshooting Guide](https://kubespray.io/#/docs/troubleshooting)

## 🚀 Scripts de Conveniencia

### Docker Setup Script (Recomendado)
Guarda este script como `kubespray-docker-setup.sh` para instalación rápida con Docker:
```bash
#!/bin/bash
# Instalación rápida de Kubespray con Docker

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Configurando Kubespray con Docker...${NC}"

# 1. Verificar Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker no está instalado. Instálalo primero.${NC}"
    exit 1
fi

# 2. Clonar Kubespray
echo -e "${BLUE}📥 Clonando Kubespray...${NC}"
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray

# 3. Descargar imagen de Kubespray
echo -e "${BLUE}📥 Descargando imagen de Kubespray v2.28.0...${NC}"
docker pull quay.io/kubespray/kubespray:v2.28.0

# 4. Verificar clave SSH
if [ ! -f "${HOME}/.ssh/id_rsa" ]; then
    echo -e "${RED}❌ No se encontró clave SSH privada en ${HOME}/.ssh/id_rsa${NC}"
    echo -e "${BLUE}💡 Genera una con: ssh-keygen -t rsa -b 4096${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Kubespray configurado con Docker${NC}"
echo -e "${BLUE}📝 Edita inventory/sample/inventory.ini con tus IPs${NC}"
echo -e "${BLUE}🚀 Luego ejecuta:${NC}"
echo -e "${BLUE}docker run --rm -it \\${NC}"
echo -e "${BLUE}  --mount type=bind,source=\"\$(pwd)\"/inventory/sample,dst=/inventory \\${NC}"
echo -e "${BLUE}  --mount type=bind,source=\"\${HOME}\"/.ssh/id_rsa,dst=/root/.ssh/id_rsa \\${NC}"
echo -e "${BLUE}  quay.io/kubespray/kubespray:v2.28.0 bash${NC}"
```

### Setup Script Tradicional
Guarda este script como `kubespray-setup.sh` para instalación local:
```bash
#!/bin/bash
# Instalación rápida de Kubespray tradicional

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Instalando Kubespray localmente...${NC}"

# 1. Instalar dependencias
sudo apt update && sudo apt install -y python3-pip git
pip3 install ansible netaddr

# 2. Clonar Kubespray
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
pip3 install -r requirements.txt

# 3. Preparar inventario
cp -rfp inventory/sample inventory/mycluster

echo -e "${GREEN}✅ Kubespray instalado. Edita inventory/mycluster/hosts.yaml con tus IPs${NC}"
echo -e "${BLUE}📝 Luego ejecuta: ansible-playbook -i inventory/mycluster/hosts.yaml --become cluster.yml${NC}"
```

### Verificación Rápida
```bash
# Script para verificar estado del cluster
kubectl get nodes -o wide && \
kubectl get pods --all-namespaces | grep -E "(kube-system|default)" && \
kubectl cluster-info
```

---

**💡 Consejo**: Kubespray con Docker elimina problemas de dependencias y es ideal para despliegues de producción donde necesitas control total sobre la configuración del cluster.

**🐳 Ventaja Docker**: Sin necesidad de instalar Ansible, Python o dependencias locales. Todo viene incluido en la imagen oficial.

**📋 Copia fácil**: En GitHub, haz clic en el botón de copia que aparece al pasar el cursor sobre cualquier bloque de código.
