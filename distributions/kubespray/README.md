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

## 🚀 Instalación Rápida

### Prerrequisitos
```bash
# 1. Instalar Ansible
sudo apt update && sudo apt install -y python3-pip
pip3 install ansible netaddr

# 2. Clonar Kubespray
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray

# 3. Instalar dependencias
sudo pip3 install -r requirements.txt
```

### Configuración Básica
```bash
# 1. Copiar inventario de ejemplo
cp -rfp inventory/sample inventory/mycluster

# 2. Configurar IPs de los nodos (EDITAR CON TUS IPs)
declare -a IPS=(10.10.1.3 10.10.1.4 10.10.1.5)
CONFIG_FILE=inventory/mycluster/hosts.yaml python3 contrib/inventory_builder/inventory.py ${IPS[@]}

# 3. Desplegar cluster
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

### ⚡ Comandos de Un Solo Paso
```bash
# Instalación completa de Ansible + dependencias
curl -fsSL https://raw.githubusercontent.com/kubernetes-sigs/kubespray/master/requirements.txt | sudo pip3 install -r /dev/stdin && sudo apt update && sudo apt install -y python3-pip ansible

# Configuración rápida de inventario (EDITAR IPs)
declare -a IPS=(10.10.1.3 10.10.1.4 10.10.1.5) && CONFIG_FILE=inventory/mycluster/hosts.yaml python3 contrib/inventory_builder/inventory.py ${IPS[@]}
```

### Despliegue Inicial
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

### Health Checks
```bash
# Verificar estado del cluster
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml --tags=health-check

# Verificar conectividad de red
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml --tags=network-test
```

### Logs y Debugging
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

### Quick Setup Script
Guarda este script como `kubespray-setup.sh` para instalación rápida:
```bash
#!/bin/bash
# Instalación rápida de Kubespray

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Instalando Kubespray...${NC}"

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

**💡 Consejo**: Kubespray es ideal para despliegues de producción donde necesitas control total sobre la configuración del cluster y automatización completa del proceso de despliegue.

**📋 Copia fácil**: En GitHub, haz clic en el botón de copia que aparece al pasar el cursor sobre cualquier bloque de código.
