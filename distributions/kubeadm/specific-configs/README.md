# Configuraciones Específicas de kubeadm

Esta carpeta contiene configuraciones y ejemplos que aprovechan características específicas de kubeadm (herramienta oficial para crear clusters Kubernetes) que lo diferencian de otras distribuciones.

## 🎯 Contenido Específico de kubeadm

### 1. Configuraciones de Inicialización del Cluster

#### Configuración Completa de kubeadm
```yaml
# kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "192.168.1.100"
  bindPort: 6443
nodeRegistration:
  criSocket: "unix:///var/run/containerd/containerd.sock"
  kubeletExtraArgs:
    cgroup-driver: "systemd"
    container-runtime: "remote"
    container-runtime-endpoint: "unix:///var/run/containerd/containerd.sock"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: "v1.28.2"
clusterName: "production-cluster"
controlPlaneEndpoint: "k8s-api.example.com:6443"
networking:
  serviceSubnet: "10.96.0.0/12"
  podSubnet: "10.244.0.0/16"
  dnsDomain: "cluster.local"
apiServer:
  certSANs:
  - "k8s-api.example.com"
  - "192.168.1.100"
  - "127.0.0.1"
  extraArgs:
    audit-log-maxage: "30"
    audit-log-maxbackup: "10"
    audit-log-maxsize: "100"
    audit-log-path: "/var/log/kubernetes/audit.log"
    enable-admission-plugins: "NodeRestriction,ResourceQuota,PodSecurityPolicy"
  extraVolumes:
  - name: "audit-logs"
    hostPath: "/var/log/kubernetes"
    mountPath: "/var/log/kubernetes"
    pathType: DirectoryOrCreate
controllerManager:
  extraArgs:
    bind-address: "0.0.0.0"
    cluster-signing-duration: "8760h0m0s"
scheduler:
  extraArgs:
    bind-address: "0.0.0.0"
etcd:
  local:
    dataDir: "/var/lib/etcd"
    extraArgs:
      listen-metrics-urls: "http://0.0.0.0:2381"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: KubeletConfiguration
cgroupDriver: "systemd"
clusterDNS:
- "10.96.0.10"
clusterDomain: "cluster.local"
resolvConf: "/etc/resolv.conf"
runtimeRequestTimeout: "10m"
systemReserved:
  cpu: "100m"
  memory: "256Mi"
kubeReserved:
  cpu: "100m"
  memory: "256Mi"
evictionHard:
  memory.available: "100Mi"
  nodefs.available: "10%"
  imagefs.available: "15%"
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true
```

#### Configuración de High Availability (HA)
```yaml
# kubeadm-ha-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "192.168.1.100"
  bindPort: 6443
nodeRegistration:
  criSocket: "unix:///var/run/containerd/containerd.sock"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: "v1.28.2"
clusterName: "ha-production-cluster"
controlPlaneEndpoint: "k8s-lb.example.com:6443"  # Load Balancer
networking:
  serviceSubnet: "10.96.0.0/12"
  podSubnet: "10.244.0.0/16"
apiServer:
  certSANs:
  - "k8s-lb.example.com"
  - "k8s-master-1.example.com"
  - "k8s-master-2.example.com"
  - "k8s-master-3.example.com"
  - "192.168.1.100"
  - "192.168.1.101"
  - "192.168.1.102"
  extraArgs:
    audit-log-maxage: "30"
    audit-log-maxbackup: "10"
    audit-log-maxsize: "100"
    audit-log-path: "/var/log/kubernetes/audit.log"
etcd:
  external:
    endpoints:
    - "https://etcd-1.example.com:2379"
    - "https://etcd-2.example.com:2379"
    - "https://etcd-3.example.com:2379"
    caFile: "/etc/kubernetes/pki/etcd/ca.crt"
    certFile: "/etc/kubernetes/pki/apiserver-etcd-client.crt"
    keyFile: "/etc/kubernetes/pki/apiserver-etcd-client.key"
```

### 2. Scripts de Instalación y Configuración

#### Instalación Completa del Cluster
```bash
#!/bin/bash
# kubeadm-cluster-setup.sh

set -e

# Variables de configuración
KUBERNETES_VERSION="1.28.2-00"
CONTAINERD_VERSION="1.7.2"
CLUSTER_NAME="production-cluster"
POD_CIDR="10.244.0.0/16"
SERVICE_CIDR="10.96.0.0/12"

echo "🚀 Setting up Kubernetes cluster with kubeadm"

# Función para instalar Docker/Containerd
install_container_runtime() {
    echo "Installing Containerd..."
    
    # Instalar dependencias
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    # Agregar repositorio de Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Instalar containerd
    apt-get update
    apt-get install -y containerd.io
    
    # Configurar containerd
    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    
    # Reiniciar y habilitar containerd
    systemctl restart containerd
    systemctl enable containerd
    
    echo "✅ Containerd installed and configured"
}

# Función para instalar kubeadm, kubelet y kubectl
install_kubernetes_tools() {
    echo "Installing Kubernetes tools..."
    
    # Agregar repositorio de Kubernetes
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
    
    # Instalar herramientas
    apt-get update
    apt-get install -y kubelet=$KUBERNETES_VERSION kubeadm=$KUBERNETES_VERSION kubectl=$KUBERNETES_VERSION
    apt-mark hold kubelet kubeadm kubectl
    
    # Configurar kubelet
    systemctl enable kubelet
    
    echo "✅ Kubernetes tools installed"
}

# Función para configurar el sistema
configure_system() {
    echo "Configuring system for Kubernetes..."
    
    # Deshabilitar swap
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    
    # Configurar módulos del kernel
    cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    
    modprobe overlay
    modprobe br_netfilter
    
    # Configurar parámetros de red
    cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    
    sysctl --system
    
    echo "✅ System configured"
}

# Función para inicializar el cluster
initialize_cluster() {
    echo "Initializing Kubernetes cluster..."
    
    # Crear archivo de configuración
    cat <<EOF > /tmp/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "$(hostname -I | awk '{print $1}')"
  bindPort: 6443
nodeRegistration:
  criSocket: "unix:///var/run/containerd/containerd.sock"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: "v${KUBERNETES_VERSION%-*}"
clusterName: "$CLUSTER_NAME"
networking:
  serviceSubnet: "$SERVICE_CIDR"
  podSubnet: "$POD_CIDR"
apiServer:
  extraArgs:
    enable-admission-plugins: "NodeRestriction,ResourceQuota"
controllerManager:
  extraArgs:
    bind-address: "0.0.0.0"
scheduler:
  extraArgs:
    bind-address: "0.0.0.0"
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
EOF
    
    # Inicializar cluster
    kubeadm init --config=/tmp/kubeadm-config.yaml --upload-certs
    
    # Configurar kubectl para el usuario
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    
    echo "✅ Cluster initialized"
}

# Función para instalar CNI (Flannel)
install_cni() {
    echo "Installing Flannel CNI..."
    
    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
    
    echo "✅ CNI installed"
}

# Función para configurar worker nodes
configure_worker_join() {
    echo "Generating worker join command..."
    
    # Generar comando de join
    kubeadm token create --print-join-command > /tmp/worker-join-command.sh
    chmod +x /tmp/worker-join-command.sh
    
    echo "✅ Worker join command saved to /tmp/worker-join-command.sh"
    echo "Run this command on worker nodes to join the cluster:"
    cat /tmp/worker-join-command.sh
}

# Función principal
main() {
    # Verificar si se ejecuta como root
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root"
        exit 1
    fi
    
    echo "Starting Kubernetes cluster setup..."
    
    configure_system
    install_container_runtime
    install_kubernetes_tools
    initialize_cluster
    install_cni
    configure_worker_join
    
    echo ""
    echo "🎉 Kubernetes cluster setup completed!"
    echo ""
    echo "Cluster info:"
    kubectl cluster-info
    echo ""
    echo "Nodes:"
    kubectl get nodes
    echo ""
    echo "To add worker nodes, run the join command from /tmp/worker-join-command.sh"
}

# Ejecutar instalación
main
```

#### Script para Worker Nodes
```bash
#!/bin/bash
# kubeadm-worker-setup.sh

set -e

KUBERNETES_VERSION="1.28.2-00"

echo "🚀 Setting up Kubernetes worker node"

# Función para instalar Containerd
install_container_runtime() {
    echo "Installing Containerd..."
    
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y containerd.io
    
    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    
    systemctl restart containerd
    systemctl enable containerd
    
    echo "✅ Containerd installed"
}

# Función para instalar herramientas de Kubernetes
install_kubernetes_tools() {
    echo "Installing Kubernetes tools..."
    
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
    
    apt-get update
    apt-get install -y kubelet=$KUBERNETES_VERSION kubeadm=$KUBERNETES_VERSION kubectl=$KUBERNETES_VERSION
    apt-mark hold kubelet kubeadm kubectl
    
    systemctl enable kubelet
    
    echo "✅ Kubernetes tools installed"
}

# Función para configurar el sistema
configure_system() {
    echo "Configuring system..."
    
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    
    cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    
    modprobe overlay
    modprobe br_netfilter
    
    cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    
    sysctl --system
    
    echo "✅ System configured"
}

# Función principal
main() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root"
        exit 1
    fi
    
    echo "Preparing worker node..."
    
    configure_system
    install_container_runtime
    install_kubernetes_tools
    
    echo ""
    echo "🎉 Worker node prepared!"
    echo ""
    echo "Now run the join command provided by the master node:"
    echo "kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
}

main
```

### 3. Configuración de etcd Externo

#### Configuración de Cluster etcd
```bash
#!/bin/bash
# etcd-cluster-setup.sh

set -e

# Variables
ETCD_VERSION="v3.5.9"
ETCD_CLUSTER_SIZE=3
ETCD_DATA_DIR="/var/lib/etcd"

# Nodos etcd (modificar según tu entorno)
ETCD_NODES=(
    "etcd-1=192.168.1.10"
    "etcd-2=192.168.1.11"
    "etcd-3=192.168.1.12"
)

# Función para instalar etcd
install_etcd() {
    local node_name=$1
    local node_ip=$2
    
    echo "Installing etcd on $node_name ($node_ip)..."
    
    # Descargar etcd
    curl -L https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz -o etcd.tar.gz
    tar xzf etcd.tar.gz
    mv etcd-${ETCD_VERSION}-linux-amd64/etcd* /usr/local/bin/
    rm -rf etcd.tar.gz etcd-${ETCD_VERSION}-linux-amd64
    
    # Crear usuario y directorios
    useradd -r -s /bin/false etcd
    mkdir -p $ETCD_DATA_DIR
    chown etcd:etcd $ETCD_DATA_DIR
    
    # Crear configuración
    cat <<EOF > /etc/etcd/etcd.conf
ETCD_NAME=$node_name
ETCD_DATA_DIR=$ETCD_DATA_DIR
ETCD_LISTEN_PEER_URLS=https://$node_ip:2380
ETCD_LISTEN_CLIENT_URLS=https://$node_ip:2379,https://127.0.0.1:2379
ETCD_INITIAL_ADVERTISE_PEER_URLS=https://$node_ip:2380
ETCD_ADVERTISE_CLIENT_URLS=https://$node_ip:2379
ETCD_INITIAL_CLUSTER=$(IFS=,; echo "${ETCD_NODES[*]}" | sed 's/=/=https:\/\//g; s/,/=https:\/\//g; s/$/:2380/g')
ETCD_INITIAL_CLUSTER_STATE=new
ETCD_INITIAL_CLUSTER_TOKEN=etcd-cluster-token
EOF
    
    # Crear servicio systemd
    cat <<EOF > /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/etcd-io/etcd
Conflicts=etcd.service
Conflicts=etcd2.service

[Service]
Type=notify
Restart=always
RestartSec=5s
LimitNOFILE=40000
TimeoutStartSec=0

User=etcd
EnvironmentFile=/etc/etcd/etcd.conf
ExecStart=/usr/local/bin/etcd
Delegate=yes
KillMode=process
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF
    
    # Iniciar servicio
    systemctl daemon-reload
    systemctl enable etcd
    systemctl start etcd
    
    echo "✅ etcd installed and started on $node_name"
}

echo "Setting up etcd cluster..."

# Instalar en el nodo actual
CURRENT_IP=$(hostname -I | awk '{print $1}')
CURRENT_NODE="etcd-$(echo $CURRENT_IP | cut -d. -f4)"

install_etcd $CURRENT_NODE $CURRENT_IP

echo "✅ etcd cluster node configured"
echo "Repeat this process on other nodes with their respective IPs"
```

### 4. Configuración de Load Balancer para HA

#### HAProxy para API Server
```bash
#!/bin/bash
# haproxy-setup.sh

set -e

# Variables
MASTER_NODES=(
    "192.168.1.100:6443"
    "192.168.1.101:6443"
    "192.168.1.102:6443"
)
VIP="192.168.1.10"  # Virtual IP

echo "Setting up HAProxy for Kubernetes API Server..."

# Instalar HAProxy
apt-get update
apt-get install -y haproxy keepalived

# Configurar HAProxy
cat <<EOF > /etc/haproxy/haproxy.cfg
global
    log stdout local0
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    mode tcp
    log global
    option tcplog
    option dontlognull
    option redispatch
    retries 3
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend k8s-api
    bind *:6443
    mode tcp
    default_backend k8s-masters

backend k8s-masters
    mode tcp
    balance roundrobin
    option tcp-check
EOF

# Agregar masters al backend
for i in "${!MASTER_NODES[@]}"; do
    node_ip=$(echo ${MASTER_NODES[$i]} | cut -d: -f1)
    node_port=$(echo ${MASTER_NODES[$i]} | cut -d: -f2)
    echo "    server master-$((i+1)) $node_ip:$node_port check inter 2000 rise 2 fall 3" >> /etc/haproxy/haproxy.cfg
done

# Configurar Keepalived para VIP
cat <<EOF > /etc/keepalived/keepalived.conf
vrrp_script chk_haproxy {
    script "/bin/bash -c 'if [[ \$(netstat -nlp | grep :6443) ]]; then exit 0; else exit 1; fi'"
    interval 2
    weight -2
    fall 3
    rise 2
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 2
    authentication {
        auth_type PASS
        auth_pass changeme
    }
    virtual_ipaddress {
        $VIP/24
    }
    track_script {
        chk_haproxy
    }
}
EOF

# Iniciar servicios
systemctl enable haproxy keepalived
systemctl start haproxy keepalived

echo "✅ HAProxy and Keepalived configured"
echo "API Server available at: https://$VIP:6443"
```

### 5. Configuración de Upgrade del Cluster

#### Script para Upgrade de kubeadm
```bash
#!/bin/bash
# kubeadm-upgrade.sh

set -e

CURRENT_VERSION=$(kubectl version --short | grep "Server Version" | cut -d: -f2 | tr -d ' ')
TARGET_VERSION=${1:-"v1.28.3"}

echo "🔄 Upgrading Kubernetes cluster from $CURRENT_VERSION to $TARGET_VERSION"

# Función para upgrade del control plane
upgrade_control_plane() {
    echo "Upgrading control plane..."
    
    # Actualizar kubeadm
    apt-get update
    apt-get install -y kubeadm=${TARGET_VERSION#v}-00
    
    # Verificar plan de upgrade
    kubeadm upgrade plan
    
    # Aplicar upgrade
    kubeadm upgrade apply $TARGET_VERSION -y
    
    # Drenar nodo
    kubectl drain $(hostname) --ignore-daemonsets --delete-emptydir-data
    
    # Actualizar kubelet y kubectl
    apt-get install -y kubelet=${TARGET_VERSION#v}-00 kubectl=${TARGET_VERSION#v}-00
    
    # Reiniciar kubelet
    systemctl daemon-reload
    systemctl restart kubelet
    
    # Hacer nodo schedulable nuevamente
    kubectl uncordon $(hostname)
    
    echo "✅ Control plane upgraded"
}

# Función para upgrade de workers
upgrade_worker() {
    echo "Upgrading worker node..."
    
    # Actualizar kubeadm
    apt-get update
    apt-get install -y kubeadm=${TARGET_VERSION#v}-00
    
    # Upgrade configuración del nodo
    kubeadm upgrade node
    
    # Drenar nodo (ejecutar desde control plane)
    echo "Run from control plane: kubectl drain $(hostname) --ignore-daemonsets --delete-emptydir-data"
    read -p "Press enter when node is drained..."
    
    # Actualizar kubelet y kubectl
    apt-get install -y kubelet=${TARGET_VERSION#v}-00 kubectl=${TARGET_VERSION#v}-00
    
    # Reiniciar kubelet
    systemctl daemon-reload
    systemctl restart kubelet
    
    # Hacer nodo schedulable (ejecutar desde control plane)
    echo "Run from control plane: kubectl uncordon $(hostname)"
    
    echo "✅ Worker node upgraded"
}

# Función para verificar upgrade
verify_upgrade() {
    echo "Verifying cluster state..."
    
    kubectl get nodes
    kubectl version --short
    kubectl get pods --all-namespaces
    
    echo "✅ Cluster upgrade completed successfully"
}

# Función principal
main() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root"
        exit 1
    fi
    
    # Verificar si es control plane o worker
    if [ -f /etc/kubernetes/admin.conf ]; then
        upgrade_control_plane
    else
        upgrade_worker
    fi
    
    verify_upgrade
}

main
```

### 6. Configuración de Backup y Restore

#### Script de Backup para kubeadm
```bash
#!/bin/bash
# kubeadm-backup.sh

set -e

BACKUP_DIR="/opt/k8s-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"

echo "🔄 Creating Kubernetes cluster backup..."

# Función para backup de etcd
backup_etcd() {
    echo "Backing up etcd..."
    
    mkdir -p $BACKUP_PATH/etcd
    
    # Backup directo desde etcd
    ETCDCTL_API=3 etcdctl snapshot save $BACKUP_PATH/etcd/snapshot.db \
        --endpoints=https://127.0.0.1:2379 \
        --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
        --key=/etc/kubernetes/pki/etcd/healthcheck-client.key
    
    echo "✅ etcd backup completed"
}

# Función para backup de certificados
backup_certificates() {
    echo "Backing up certificates..."
    
    mkdir -p $BACKUP_PATH/pki
    cp -r /etc/kubernetes/pki/* $BACKUP_PATH/pki/
    
    echo "✅ Certificates backup completed"
}

# Función para backup de configuraciones
backup_configs() {
    echo "Backing up configurations..."
    
    mkdir -p $BACKUP_PATH/configs
    cp -r /etc/kubernetes/*.conf $BACKUP_PATH/configs/ 2>/dev/null || true
    cp -r /etc/kubernetes/manifests $BACKUP_PATH/configs/ 2>/dev/null || true
    
    echo "✅ Configurations backup completed"
}

# Función para backup de recursos
backup_resources() {
    echo "Backing up cluster resources..."
    
    mkdir -p $BACKUP_PATH/resources
    
    # Backup de todos los recursos
    for resource in $(kubectl api-resources --namespaced=true --verbs=list -o name); do
        echo "Backing up $resource..."
        kubectl get $resource --all-namespaces -o yaml > "$BACKUP_PATH/resources/$resource.yaml" 2>/dev/null || true
    done
    
    # Backup de recursos cluster-scoped
    for resource in $(kubectl api-resources --namespaced=false --verbs=list -o name); do
        echo "Backing up cluster-scoped $resource..."
        kubectl get $resource -o yaml > "$BACKUP_PATH/resources/cluster-$resource.yaml" 2>/dev/null || true
    done
    
    echo "✅ Resources backup completed"
}

# Función principal
main() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root"
        exit 1
    fi
    
    mkdir -p $BACKUP_DIR
    
    echo "Creating backup in: $BACKUP_PATH"
    
    backup_etcd
    backup_certificates
    backup_configs
    backup_resources
    
    # Crear archivo de información
    cat <<EOF > $BACKUP_PATH/backup-info.txt
Backup Date: $(date)
Kubernetes Version: $(kubectl version --short | grep "Server Version")
Node Info: $(kubectl get nodes -o wide)
Backup Path: $BACKUP_PATH
EOF
    
    # Comprimir backup
    cd $BACKUP_DIR
    tar -czf "$TIMESTAMP.tar.gz" "$TIMESTAMP"
    rm -rf "$TIMESTAMP"
    
    echo ""
    echo "🎉 Backup completed successfully!"
    echo "Backup file: $BACKUP_DIR/$TIMESTAMP.tar.gz"
    echo ""
    
    # Limpieza de backups antiguos (mantener últimos 7 días)
    find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
}

main
```

### 7. Configuración de Monitoring Nativo

#### Configuración de Metrics Server
```yaml
# metrics-server-config.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    k8s-app: metrics-server
  name: system:aggregated-metrics-reader
rules:
- apiGroups: [""]
  resources: ["pods", "nodes", "nodes/metrics", "nodes/proxy"]
  verbs: ["get", "list", "watch"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  strategy:
    rollingUpdate:
      maxUnavailable: 0
  template:
    metadata:
      labels:
        k8s-app: metrics-server
    spec:
      containers:
      - args:
        - --cert-dir=/tmp
        - --secure-port=4443
        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
        - --kubelet-use-node-status-port
        - --metric-resolution=15s
        - --kubelet-insecure-tls  # Para clusters de desarrollo
        image: k8s.gcr.io/metrics-server/metrics-server:v0.6.4
        imagePullPolicy: IfNotPresent
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /livez
            port: https
            scheme: HTTPS
          periodSeconds: 10
        name: metrics-server
        ports:
        - containerPort: 4443
          name: https
          protocol: TCP
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /readyz
            port: https
            scheme: HTTPS
          initialDelaySeconds: 20
          periodSeconds: 10
        resources:
          requests:
            cpu: 100m
            memory: 200Mi
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
        volumeMounts:
        - mountPath: /tmp
          name: tmp-dir
      nodeSelector:
        kubernetes.io/os: linux
      priorityClassName: system-cluster-critical
      serviceAccountName: metrics-server
      volumes:
      - emptyDir: {}
        name: tmp-dir
```

## 🔧 Comandos Útiles Específicos de kubeadm

### Gestión del Cluster
```bash
# Ver configuración actual
kubeadm config view

# Generar nuevo token
kubeadm token create --print-join-command

# Listar tokens
kubeadm token list

# Reset completo del nodo
kubeadm reset --force

# Upgrade del cluster
kubeadm upgrade plan
kubeadm upgrade apply v1.28.3
```

### Certificados
```bash
# Ver certificados
kubeadm certs check-expiration

# Renovar certificados
kubeadm certs renew all

# Renovar certificado específico
kubeadm certs renew apiserver
```

### etcd
```bash
# Backup de etcd
ETCDCTL_API=3 etcdctl snapshot save backup.db

# Restore de etcd
ETCDCTL_API=3 etcdctl snapshot restore backup.db

# Ver miembros de etcd
ETCDCTL_API=3 etcdctl member list
```

## 📝 Notas Importantes

1. **Producción**: kubeadm es la herramienta oficial para clusters de producción
2. **Flexibilidad**: Máximo control sobre configuración y componentes
3. **HA**: Soporte nativo para alta disponibilidad con múltiples control planes
4. **Upgrades**: Proceso de upgrade controlado y documentado
5. **Certificados**: Gestión automática de certificados con renovación
6. **etcd**: Configuración flexible (embebido o externo)

## 🔗 Enlaces Útiles

- [Documentación oficial de kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Configuración de HA](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/)
- [Troubleshooting](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/)
