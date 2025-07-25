# Group Variables para Kubespray

Esta carpeta contiene configuraciones específicas para diferentes grupos de nodos en el cluster de Kubernetes.

## 📋 Contenido

### all.yml
Variables globales que aplican a todos los nodos del cluster.

### k8s_cluster.yml
Configuraciones específicas del cluster de Kubernetes.

### etcd.yml
Configuraciones del cluster etcd.

### addons.yml
Configuración de addons y componentes opcionales.

## 🎯 Configuraciones Incluidas

### Cluster de Producción
- **Alta disponibilidad**: Configuraciones para resilencia
- **Seguridad**: RBAC, Network Policies, Pod Security Standards
- **Performance**: Optimizaciones para cargas de trabajo pesadas
- **Monitoreo**: Métricas y logging avanzado

### Redes y Conectividad
- **CNI Plugin**: Calico con configuraciones avanzadas
- **Service Mesh**: Preparación para Istio
- **Ingress**: NGINX Ingress Controller
- **DNS**: CoreDNS optimizado

### Storage y Persistencia
- **CSI Drivers**: Soporte para múltiples proveedores
- **Storage Classes**: Configuraciones por tipo de workload
- **Backup**: Configuraciones de Velero

## 🛠️ Estructura de Variables

### Jerarquía de Precedencia
1. **host_vars/**: Variables específicas por host
2. **group_vars/**: Variables por grupo (estas carpetas)
3. **inventory**: Variables en el archivo de inventario
4. **defaults**: Valores por defecto de Kubespray

### Grupos Principales
- **all**: Variables para todos los hosts
- **k8s_cluster**: Variables para el cluster de Kubernetes
- **kube_control_plane**: Variables específicas para masters
- **kube_node**: Variables específicas para workers
- **etcd**: Variables para el cluster etcd

## 📝 Personalización

### Modificar Configuraciones
```bash
# Editar variables globales
vi group_vars/all.yml

# Editar configuración del cluster
vi group_vars/k8s_cluster.yml

# Verificar variables aplicadas
ansible-inventory -i inventory/mycluster/hosts.yaml --host master1
```

### Validar Configuración
```bash
# Dry-run para ver cambios
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml --check

# Aplicar solo configuración específica
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml --tags=k8s-cluster
```
