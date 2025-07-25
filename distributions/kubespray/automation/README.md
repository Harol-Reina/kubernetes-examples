# Scripts de Automatización - Kubespray

Esta carpeta contiene scripts que automatizan las operaciones más comunes de gestión de clusters de Kubernetes usando Kubespray.

## 📋 Scripts Disponibles

### 🚀 deploy-cluster.sh
**Propósito**: Despliegue automatizado de clusters de Kubernetes
```bash
./deploy-cluster.sh [production|development|testing]
```

**Características**:
- Verificación automática de prerrequisitos
- Configuración de inventario según tipo de cluster
- Validación de conectividad SSH
- Despliegue completo del cluster
- Configuración automática de kubectl
- Verificación post-instalación

### ⬆️ upgrade-cluster.sh
**Propósito**: Actualización automatizada de versiones de Kubernetes
```bash
./upgrade-cluster.sh [VERSION]
```

**Características**:
- Backup automático antes del upgrade
- Verificaciones pre-upgrade del estado del cluster
- Actualización de configuración de Kubespray
- Upgrade sin downtime (rolling update)
- Verificación post-upgrade
- Rollback automático en caso de error

### 📈 scale-cluster.sh
**Propósito**: Escalado automático del cluster (añadir/remover nodos)
```bash
./scale-cluster.sh [add-workers|remove-workers|add-masters] [COUNT]
```

**Características**:
- Adición de nodos worker
- Remoción segura de nodos worker (con drenado)
- Adición de nodos master para alta disponibilidad
- Verificación de conectividad automática
- Validación del estado post-escalado

### 💾 backup-cluster.sh
**Propósito**: Backup completo del cluster y sus datos
```bash
./backup-cluster.sh [full|etcd|resources]
```

**Características**:
- Backup de etcd (estado del cluster)
- Backup de recursos de Kubernetes
- Backup de configuraciones
- Compresión automática
- Validación de integridad
- Limpieza automática de backups antiguos

## 🛠️ Configuración

### Variables de Entorno
```bash
# Directorio de Kubespray
export KUBESPRAY_DIR="/path/to/kubespray"

# Días de retención para backups
export RETENTION_DAYS=30
```

### Prerrequisitos
- **Ansible** instalado y configurado
- **kubectl** instalado
- **SSH access** a todos los nodos del cluster
- **Sudo privileges** en todos los nodos
- **Kubespray** clonado y configurado

## 🚀 Ejemplos de Uso

### Despliegue de Cluster de Producción
```bash
# Preparar inventario con 3 masters + 5 workers
vi ../specific-configs/inventory/hosts-ha.yaml

# Desplegar cluster
./deploy-cluster.sh production

# Verificar deployment
kubectl get nodes
kubectl get pods --all-namespaces
```

### Escalado del Cluster
```bash
# Añadir 2 workers
./scale-cluster.sh add-workers 2

# Añadir 1 master adicional para HA
./scale-cluster.sh add-masters 1

# Remover worker específico
./scale-cluster.sh remove-workers 1
```

### Upgrade de Kubernetes
```bash
# Verificar versión actual
kubectl version --short

# Upgrade a nueva versión
./upgrade-cluster.sh v1.28.8

# Verificar upgrade
kubectl get nodes -o wide
```

### Backup y Restore
```bash
# Backup completo
./backup-cluster.sh full

# Backup solo de etcd
./backup-cluster.sh etcd

# Backup programado (agregar a cron)
0 2 * * * /path/to/backup-cluster.sh full
```

## 🔧 Personalización

### Modificar Configuraciones
Los scripts usan las configuraciones en `../specific-configs/`:
- **inventory/**: Inventarios de Ansible
- **group_vars/**: Variables por grupos de nodos
- **custom-addons/**: Addons personalizados

### Añadir Nuevos Scripts
Para crear scripts adicionales, sigue el patrón:
```bash
#!/bin/bash
set -euo pipefail

# Colores y funciones de logging
source ./common-functions.sh

# Tu lógica aquí
main() {
    log_info "Iniciando operación..."
    # ...
}

main "$@"
```

## 📝 Logging y Debug

### Logs Detallados
```bash
# Activar modo verbose en Ansible
export ANSIBLE_VERBOSE=true

# Debug de Kubespray
./deploy-cluster.sh production 2>&1 | tee deployment.log
```

### Troubleshooting
```bash
# Verificar conectividad
ansible all -i inventory/mycluster/hosts.yaml -m ping

# Verificar configuración
ansible-inventory -i inventory/mycluster/hosts.yaml --list

# Dry-run antes de ejecutar
ansible-playbook cluster.yml --check
```

## 🔒 Seguridad

### Buenas Prácticas
- **SSH Keys**: Usar autenticación basada en llaves
- **Sudo**: Configurar sudo sin contraseña para automatización
- **Backups**: Encriptar backups que contengan secrets
- **Logs**: No logear información sensible

### Permisos
```bash
# Configurar permisos seguros para scripts
chmod 750 *.sh
chown root:k8s-admins *.sh

# Configurar sudo para usuario de automatización
echo "k8s-deploy ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/k8s-deploy
```

## 🚨 Recuperación ante Desastres

### Escenarios de Recuperación
1. **Fallo de nodo master**: Usar scripts de escalado para reemplazar
2. **Corrupción de etcd**: Restaurar desde backup
3. **Fallo de upgrade**: Rollback automático incluido
4. **Pérdida de configuración**: Restaurar desde backup de configuración

### Plan de Contingencia
```bash
# 1. Backup inmediato
./backup-cluster.sh full

# 2. Verificar estado
kubectl get nodes
kubectl get pods --all-namespaces

# 3. Ejecutar recuperación según el problema
# Ver documentación específica en ../README.md
```

---

**💡 Tip**: Estos scripts están diseñados para ser idempotentes y seguros. Siempre realizan verificaciones antes de ejecutar operaciones destructivas.
