# Inventario de Kubespray - Cluster de Producción

Esta carpeta contiene templates y ejemplos de inventarios de Ansible para diferentes topologías de clusters de Kubernetes usando Kubespray.

## 📋 Contenido

### hosts.yaml
Template principal de inventario con ejemplos para diferentes configuraciones de cluster.

### hosts-ha.yaml  
Configuración de alta disponibilidad con múltiples masters y load balancer externo.

### hosts-single-master.yaml
Configuración simple con un solo master para desarrollo o testing.

### hosts-large-cluster.yaml
Configuración para clusters grandes con separación de roles.

## 🎯 Configuraciones Incluidas

### Cluster de Alta Disponibilidad (3 Masters + 5 Workers)
```yaml
all:
  hosts:
    master1:
      ansible_host: 10.0.1.10
      ip: 10.0.1.10
    master2:
      ansible_host: 10.0.1.11
      ip: 10.0.1.11
    master3:
      ansible_host: 10.0.1.12
      ip: 10.0.1.12
    worker1:
      ansible_host: 10.0.1.20
      ip: 10.0.1.20
    worker2:
      ansible_host: 10.0.1.21
      ip: 10.0.1.21
    worker3:
      ansible_host: 10.0.1.22
      ip: 10.0.1.22
    worker4:
      ansible_host: 10.0.1.23
      ip: 10.0.1.23
    worker5:
      ansible_host: 10.0.1.24
      ip: 10.0.1.24
  children:
    kube_control_plane:
      hosts:
        master1:
        master2:
        master3:
    kube_node:
      hosts:
        worker1:
        worker2:
        worker3:
        worker4:
        worker5:
    etcd:
      hosts:
        master1:
        master2:
        master3:
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
    calico_rr:
      hosts: {}
```

### Cluster de Desarrollo (1 Master + 2 Workers)
```yaml
all:
  hosts:
    master1:
      ansible_host: 192.168.1.10
      ip: 192.168.1.10
    worker1:
      ansible_host: 192.168.1.20
      ip: 192.168.1.20
    worker2:
      ansible_host: 192.168.1.21
      ip: 192.168.1.21
  children:
    kube_control_plane:
      hosts:
        master1:
    kube_node:
      hosts:
        worker1:
        worker2:
    etcd:
      hosts:
        master1:
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
```

## 🛠️ Cómo Usar

### 1. Generar Inventario Automáticamente
```bash
# Definir IPs de los nodos
declare -a IPS=(10.0.1.10 10.0.1.11 10.0.1.12 10.0.1.20 10.0.1.21)

# Generar inventario
CONFIG_FILE=inventory/mycluster/hosts.yaml python3 contrib/inventory_builder/inventory.py ${IPS[@]}
```

### 2. Personalizar Manualmente
```bash
# Copiar template
cp hosts-ha.yaml inventory/mycluster/hosts.yaml

# Editar con tus IPs y configuraciones
vi inventory/mycluster/hosts.yaml
```

### 3. Validar Inventario
```bash
# Verificar conectividad
ansible all -i inventory/mycluster/hosts.yaml -m ping

# Verificar configuración
ansible-inventory -i inventory/mycluster/hosts.yaml --list
```

## ⚙️ Variables de Configuración

### Variables por Host
```yaml
# En el inventario
master1:
  ansible_host: 10.0.1.10
  ip: 10.0.1.10
  ansible_user: ubuntu
  ansible_ssh_private_key_file: ~/.ssh/id_rsa
  # Variables específicas del nodo
  kube_node_taints:
    - key: "node-role.kubernetes.io/master"
      effect: "NoSchedule"
```

### Variables por Grupo
```yaml
# En group_vars/kube_control_plane/kube-control-plane.yml
kube_apiserver_bind_address: 0.0.0.0
kube_apiserver_port: 6443
cluster_name: production-cluster
```

## 📝 Notas Importantes

### Requisitos de Red
- **Conectividad SSH**: Todos los nodos deben ser accesibles por SSH
- **Sudoers**: Usuario debe tener privilegios sudo sin contraseña
- **Puertos**: Los puertos de Kubernetes deben estar abiertos entre nodos

### Configuración SSH
```bash
# Configurar SSH key-based authentication
ssh-copy-id -i ~/.ssh/id_rsa.pub user@node-ip

# Verificar acceso sin contraseña
ssh user@node-ip 'sudo whoami'
```

### Distribución de Roles
- **kube_control_plane**: Nodos master (mínimo 1, recomendado 3 para HA)
- **kube_node**: Nodos worker (donde corren las aplicaciones)
- **etcd**: Nodos etcd (pueden ser los mismos que master o separados)
- **calico_rr**: Route reflectors para Calico (opcional, para clusters grandes)
