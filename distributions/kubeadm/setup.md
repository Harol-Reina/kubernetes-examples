# Configuración y Setup de kubeadm

kubeadm es la herramienta oficial de Kubernetes para crear y gestionar clusters de Kubernetes de forma estandarizada. Es ideal para deployments de producción que requieren control total sobre la configuración del cluster.

## Tabla de Contenidos

1. [¿Qué es kubeadm?](#qué-es-kubeadm)
2. [Prerequisitos](#prerequisitos)
3. [Instalación de Componentes](#instalación-de-componentes)
4. [Configuración del Master Node](#configuración-del-master-node)
5. [Unir Worker Nodes](#unir-worker-nodes)
6. [Alta Disponibilidad (HA)](#alta-disponibilidad-ha)
7. [Networking (CNI)](#networking-cni)
8. [Storage](#storage)
9. [Seguridad](#seguridad)
10. [Monitoreo y Observabilidad](#monitoreo-y-observabilidad)
11. [Backup y Restore](#backup-y-restore)
12. [Actualizaciones](#actualizaciones)
13. [Troubleshooting](#troubleshooting)
14. [Mejores Prácticas](#mejores-prácticas)

---

## ¿Qué es kubeadm?

kubeadm es una herramienta que ayuda a crear clusters de Kubernetes que siguen las mejores prácticas. Automatiza muchos aspectos de la configuración pero permite personalización avanzada.

### Características Principales

- **Estándar**: Sigue las mejores prácticas oficiales de Kubernetes
- **Modular**: Permite customización de cada componente
- **HA Ready**: Soporte nativo para alta disponibilidad
- **Upgrades**: Sistema de actualizaciones integrado
- **Certificados**: Gestión automática de certificados PKI
- **Bootstrapping**: Proceso de inicialización seguro

### Arquitectura de Cluster

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Master Node   │    │   Master Node   │    │   Master Node   │
│                 │    │                 │    │                 │
│  ┌─────────────┐│    │  ┌─────────────┐│    │  ┌─────────────┐│
│  │ kube-apiserver││   │  │ kube-apiserver││   │  │ kube-apiserver││
│  ├─────────────┤│    │  ├─────────────┤│    │  ├─────────────┤│
│  │etcd         ││    │  │etcd         ││    │  │etcd         ││
│  ├─────────────┤│    │  ├─────────────┤│    │  ├─────────────┤│
│  │controller-mgr││   │  │controller-mgr││   │  │controller-mgr││
│  ├─────────────┤│    │  ├─────────────┤│    │  ├─────────────┤│
│  │scheduler    ││    │  │scheduler    ││    │  │scheduler    ││
│  └─────────────┘│    │  └─────────────┘│    │  └─────────────┘│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Worker Node 1  │    │  Worker Node 2  │    │  Worker Node N  │
│                 │    │                 │    │                 │
│  ┌─────────────┐│    │  ┌─────────────┐│    │  ┌─────────────┐│
│  │kubelet      ││    │  │kubelet      ││    │  │kubelet      ││
│  ├─────────────┤│    │  ├─────────────┤│    │  ├─────────────┤│
│  │kube-proxy   ││    │  │kube-proxy   ││    │  │kube-proxy   ││
│  ├─────────────┤│    │  ├─────────────┤│    │  ├─────────────┤│
│  │Container    ││    │  │Container    ││    │  │Container    ││
│  │Runtime      ││    │  │Runtime      ││    │  │Runtime      ││
│  └─────────────┘│    │  └─────────────┘│    │  └─────────────┘│
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Casos de Uso

- **Producción Enterprise**: Clusters para aplicaciones críticas
- **On-Premise**: Deployments en datacenter propio
- **Bare Metal**: Instalación en servidores físicos
- **Cloud Privado**: IaaS privado
- **Compliance**: Entornos regulados que requieren control total

---

## Prerequisitos

### Requisitos del Sistema

#### Hardware Mínimo

**Master Nodes:**
- CPU: 2 cores
- RAM: 2GB
- Storage: 20GB
- Network: 1Gbps

**Worker Nodes:**
- CPU: 1 core
- RAM: 1GB
- Storage: 10GB
- Network: 1Gbps

#### Hardware Recomendado para Producción

**Master Nodes:**
- CPU: 4-8 cores
- RAM: 8-16GB
- Storage: 100GB SSD
- Network: 10Gbps

**Worker Nodes:**
- CPU: 4-16 cores
- RAM: 16-64GB
- Storage: 100GB+ SSD
- Network: 10Gbps

### Configuración del Sistema

```bash
#!/bin/bash
# prepare-nodes.sh - Ejecutar en todos los nodos

set -e

echo "🔧 Preparando nodo para Kubernetes..."

# Variables
KUBERNETES_VERSION="1.28.4"
CONTAINERD_VERSION="1.7.8"

# Deshabilitar swap
echo "🚫 Deshabilitando swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Configurar kernel modules
echo "⚙️ Configurando módulos del kernel..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Configurar parámetros de red
echo "🌐 Configurando parámetros de red..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Instalar containerd
echo "📦 Instalando containerd..."
wget https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
rm containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz

# Instalar runc
wget https://github.com/opencontainers/runc/releases/download/v1.1.9/runc.amd64
sudo install -m 755 runc.amd64 /usr/local/sbin/runc
rm runc.amd64

# Instalar CNI plugins
sudo mkdir -p /opt/cni/bin
wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.3.0.tgz
rm cni-plugins-linux-amd64-v1.3.0.tgz

# Configurar containerd
echo "⚙️ Configurando containerd..."
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Configurar systemd cgroup driver
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Crear servicio systemd para containerd
cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable containerd
sudo systemctl start containerd

# Instalar kubeadm, kubelet y kubectl
echo "🚀 Instalando componentes de Kubernetes..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet=$KUBERNETES_VERSION-00 kubeadm=$KUBERNETES_VERSION-00 kubectl=$KUBERNETES_VERSION-00
sudo apt-mark hold kubelet kubeadm kubectl

# Configurar kubelet
echo "⚙️ Configurando kubelet..."
cat <<EOF | sudo tee /etc/default/kubelet
KUBELET_EXTRA_ARGS=--container-runtime-endpoint=unix:///var/run/containerd/containerd.sock
EOF

sudo systemctl enable kubelet

echo "✅ Nodo preparado para Kubernetes"
echo "💡 Ejecutar en el master: kubeadm init"
echo "💡 Ejecutar en workers: kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>"
```

---

## Instalación de Componentes

### Configuración Avanzada de containerd

```toml
# /etc/containerd/config.toml
version = 2

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "registry.k8s.io/pause:3.9"
    
    [plugins."io.containerd.grpc.v1.cri".containerd]
      snapshotter = "overlayfs"
      default_runtime_name = "runc"
      
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
            
    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/cni/bin"
      conf_dir = "/etc/cni/net.d"
      
    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = "/etc/containerd/certs.d"
      
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://registry-1.docker.io"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
          endpoint = ["https://registry.k8s.io"]
```

### Script de Validación Pre-instalación

```bash
#!/bin/bash
# validate-prerequisites.sh

set -e

echo "🔍 Validando prerequisitos para kubeadm..."

# Función para verificar comando
check_command() {
    if command -v $1 &> /dev/null; then
        echo "✅ $1 está instalado"
        $1 --version 2>/dev/null || echo "   Versión no disponible"
    else
        echo "❌ $1 no está instalado"
        return 1
    fi
}

# Función para verificar puerto
check_port() {
    if ss -ln | grep -q ":$1 "; then
        echo "❌ Puerto $1 está en uso"
        return 1
    else
        echo "✅ Puerto $1 está disponible"
    fi
}

# Verificar swap
echo "🔍 Verificando swap..."
if [ $(cat /proc/swaps | wc -l) -gt 1 ]; then
    echo "❌ Swap está habilitado"
    echo "   Ejecutar: sudo swapoff -a"
else
    echo "✅ Swap está deshabilitado"
fi

# Verificar módulos del kernel
echo "🔍 Verificando módulos del kernel..."
for module in overlay br_netfilter; do
    if lsmod | grep -q $module; then
        echo "✅ Módulo $module cargado"
    else
        echo "❌ Módulo $module no cargado"
        echo "   Ejecutar: sudo modprobe $module"
    fi
done

# Verificar parámetros de red
echo "🔍 Verificando parámetros de red..."
for param in net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward; do
    value=$(sysctl -n $param 2>/dev/null || echo "0")
    if [ "$value" = "1" ]; then
        echo "✅ $param = 1"
    else
        echo "❌ $param = $value (debería ser 1)"
    fi
done

# Verificar comandos
echo "🔍 Verificando comandos necesarios..."
for cmd in kubeadm kubelet kubectl containerd; do
    check_command $cmd
done

# Verificar puertos (master)
echo "🔍 Verificando puertos para master node..."
master_ports=(6443 2379 2380 10250 10259 10257)
for port in "${master_ports[@]}"; do
    check_port $port
done

# Verificar recursos del sistema
echo "🔍 Verificando recursos del sistema..."
total_mem=$(free -m | awk 'NR==2{printf "%.0f", $2}')
if [ $total_mem -ge 2048 ]; then
    echo "✅ Memoria: ${total_mem}MB (>= 2GB)"
else
    echo "⚠️ Memoria: ${total_mem}MB (< 2GB recomendado)"
fi

cpu_cores=$(nproc)
if [ $cpu_cores -ge 2 ]; then
    echo "✅ CPU cores: $cpu_cores (>= 2)"
else
    echo "⚠️ CPU cores: $cpu_cores (< 2 recomendado)"
fi

# Verificar conectividad
echo "🔍 Verificando conectividad..."
if ping -c 1 registry.k8s.io &> /dev/null; then
    echo "✅ Conectividad a registry.k8s.io"
else
    echo "❌ Sin conectividad a registry.k8s.io"
fi

echo "🏁 Validación completada"
```

---

## Configuración del Master Node

### Configuración Básica

```bash
#!/bin/bash
# init-master.sh

set -e

# Variables de configuración
CLUSTER_NAME="production-cluster"
POD_SUBNET="10.244.0.0/16"
SERVICE_SUBNET="10.96.0.0/12"
KUBERNETES_VERSION="1.28.4"
CONTROL_PLANE_ENDPOINT="k8s-api.company.com:6443"

echo "🎯 Inicializando master node..."

# Crear archivo de configuración de kubeadm
cat <<EOF > kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
clusterName: ${CLUSTER_NAME}
kubernetesVersion: v${KUBERNETES_VERSION}
controlPlaneEndpoint: ${CONTROL_PLANE_ENDPOINT}
networking:
  podSubnet: ${POD_SUBNET}
  serviceSubnet: ${SERVICE_SUBNET}
etcd:
  local:
    dataDir: "/var/lib/etcd"
apiServer:
  timeoutForControlPlane: 4m0s
  certSANs:
  - "k8s-api.company.com"
  - "10.0.0.100"
  - "127.0.0.1"
  extraArgs:
    authorization-mode: "Node,RBAC"
    enable-admission-plugins: "NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota,NodeRestriction,PodSecurityPolicy"
    audit-log-path: "/var/log/audit.log"
    audit-log-maxage: "30"
    audit-log-maxbackup: "10"
    audit-log-maxsize: "100"
    audit-policy-file: "/etc/kubernetes/audit-policy.yaml"
controllerManager:
  extraArgs:
    bind-address: "0.0.0.0"
    cluster-signing-duration: "87600h"
scheduler:
  extraArgs:
    bind-address: "0.0.0.0"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $(hostname -I | awk '{print $1}')
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  kubeletExtraArgs:
    container-runtime-endpoint: unix:///var/run/containerd/containerd.sock
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
serverTLSBootstrap: true
cgroupDriver: systemd
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
EOF

# Crear política de auditoría
sudo mkdir -p /etc/kubernetes
cat <<EOF | sudo tee /etc/kubernetes/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
- level: Request
  resources:
  - group: ""
    resources: ["pods", "services", "persistentvolumeclaims"]
- level: Metadata
  omitStages:
  - RequestReceived
EOF

# Inicializar cluster
echo "🚀 Ejecutando kubeadm init..."
sudo kubeadm init --config=kubeadm-config.yaml --upload-certs

# Configurar kubectl para el usuario actual
echo "⚙️ Configurando kubectl..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Guardar información de join
echo "💾 Guardando información de join..."
kubeadm token create --print-join-command > join-worker-command.sh
chmod +x join-worker-command.sh

# Para control plane adicionales
sudo kubeadm init phase upload-certs --upload-certs | tail -n 1 > certificate-key.txt

echo "✅ Master node inicializado"
echo "📋 Comandos para unir nodos:"
echo "   Workers: $(cat join-worker-command.sh)"
echo "   Masters: $(cat join-worker-command.sh) --control-plane --certificate-key $(cat certificate-key.txt)"
```

### Configuración Avanzada para HA

```yaml
# kubeadm-ha-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
clusterName: "production-ha-cluster"
kubernetesVersion: "v1.28.4"
controlPlaneEndpoint: "lb.k8s.company.com:6443"
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
etcd:
  external:
    endpoints:
    - "https://etcd1.company.com:2379"
    - "https://etcd2.company.com:2379"
    - "https://etcd3.company.com:2379"
    caFile: "/etc/kubernetes/pki/etcd/ca.crt"
    certFile: "/etc/kubernetes/pki/apiserver-etcd-client.crt"
    keyFile: "/etc/kubernetes/pki/apiserver-etcd-client.key"
apiServer:
  timeoutForControlPlane: 4m0s
  certSANs:
  - "lb.k8s.company.com"
  - "k8s-master1.company.com"
  - "k8s-master2.company.com"
  - "k8s-master3.company.com"
  - "10.0.0.100"
  - "10.0.0.101"
  - "10.0.0.102"
  - "10.0.0.103"
  extraArgs:
    authorization-mode: "Node,RBAC"
    enable-admission-plugins: "NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota,NodeRestriction,PodSecurityPolicy"
    audit-log-path: "/var/log/kubernetes/audit.log"
    audit-log-maxage: "30"
    audit-log-maxbackup: "10"
    audit-log-maxsize: "100"
    audit-policy-file: "/etc/kubernetes/audit-policy.yaml"
    feature-gates: "ProxyTerminatingEndpoints=false"
    default-not-ready-toleration-seconds: "30"
    default-unreachable-toleration-seconds: "30"
  extraVolumes:
  - name: audit-log
    hostPath: "/var/log/kubernetes"
    mountPath: "/var/log/kubernetes"
    pathType: DirectoryOrCreate
  - name: audit-policy
    hostPath: "/etc/kubernetes/audit-policy.yaml"
    mountPath: "/etc/kubernetes/audit-policy.yaml"
    readOnly: true
    pathType: File
controllerManager:
  extraArgs:
    bind-address: "0.0.0.0"
    cluster-signing-duration: "87600h"
    node-monitor-period: "5s"
    node-monitor-grace-period: "40s"
    pod-eviction-timeout: "5m"
scheduler:
  extraArgs:
    bind-address: "0.0.0.0"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "10.0.0.101"
  bindPort: 6443
nodeRegistration:
  criSocket: "unix:///var/run/containerd/containerd.sock"
  kubeletExtraArgs:
    container-runtime-endpoint: "unix:///var/run/containerd/containerd.sock"
    pod-infra-container-image: "registry.k8s.io/pause:3.9"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
serverTLSBootstrap: true
cgroupDriver: systemd
clusterDNS:
- "10.96.0.10"
clusterDomain: "cluster.local"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
systemReserved:
  cpu: "100m"
  memory: "100Mi"
  ephemeral-storage: "1Gi"
kubeReserved:
  cpu: "100m"
  memory: "100Mi"
  ephemeral-storage: "1Gi"
evictionHard:
  memory.available: "100Mi"
  nodefs.available: "10%"
  imagefs.available: "15%"
maxPods: 110
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true
clusterCIDR: "10.244.0.0/16"
```

---

## Unir Worker Nodes

### Script Automatizado para Workers

```bash
#!/bin/bash
# join-worker.sh

set -e

MASTER_IP="${1:-10.0.0.101}"
TOKEN="${2}"
CA_CERT_HASH="${3}"

if [ -z "$TOKEN" ] || [ -z "$CA_CERT_HASH" ]; then
    echo "❌ Uso: $0 <master-ip> <token> <ca-cert-hash>"
    echo "💡 Obtener desde el master: kubeadm token create --print-join-command"
    exit 1
fi

echo "👷 Uniendo worker node al cluster..."
echo "🎯 Master: $MASTER_IP"

# Crear configuración de kubeadm para worker
cat <<EOF > kubeadm-worker-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: "${MASTER_IP}:6443"
    token: "${TOKEN}"
    caCertHashes:
    - "${CA_CERT_HASH}"
nodeRegistration:
  criSocket: "unix:///var/run/containerd/containerd.sock"
  kubeletExtraArgs:
    container-runtime-endpoint: "unix:///var/run/containerd/containerd.sock"
    node-labels: "node.kubernetes.io/worker=true"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
serverTLSBootstrap: true
cgroupDriver: systemd
clusterDNS:
- "10.96.0.10"
clusterDomain: "cluster.local"
systemReserved:
  cpu: "100m"
  memory: "100Mi"
kubeReserved:
  cpu: "100m"
  memory: "100Mi"
evictionHard:
  memory.available: "100Mi"
  nodefs.available: "10%"
maxPods: 110
EOF

# Unir al cluster
echo "🔗 Ejecutando kubeadm join..."
sudo kubeadm join --config=kubeadm-worker-config.yaml

echo "✅ Worker node unido al cluster"
echo "🔍 Verificar en el master con: kubectl get nodes"
```

### Configuración Especializada por Rol

```bash
#!/bin/bash
# configure-worker-role.sh

NODE_ROLE="${1:-general}"
NODE_NAME=$(hostname)

echo "🏷️ Configurando worker node con rol: $NODE_ROLE"

case $NODE_ROLE in
    "compute")
        echo "🖥️ Configurando nodo de compute..."
        kubectl label node $NODE_NAME node-role.kubernetes.io/compute=true
        kubectl label node $NODE_NAME workload-type=compute-intensive
        
        # Taint para cargas de compute
        kubectl taint node $NODE_NAME workload=compute:NoSchedule
        ;;
        
    "storage")
        echo "💾 Configurando nodo de storage..."
        kubectl label node $NODE_NAME node-role.kubernetes.io/storage=true
        kubectl label node $NODE_NAME workload-type=storage
        
        # Taint para storage
        kubectl taint node $NODE_NAME workload=storage:NoSchedule
        ;;
        
    "database")
        echo "🗄️ Configurando nodo de database..."
        kubectl label node $NODE_NAME node-role.kubernetes.io/database=true
        kubectl label node $NODE_NAME workload-type=database
        
        # Taint para databases
        kubectl taint node $NODE_NAME workload=database:NoSchedule
        ;;
        
    "edge")
        echo "🌐 Configurando nodo edge..."
        kubectl label node $NODE_NAME node-role.kubernetes.io/edge=true
        kubectl label node $NODE_NAME topology.kubernetes.io/zone=edge
        
        # Configuraciones específicas para edge
        kubectl taint node $NODE_NAME location=edge:NoSchedule
        ;;
        
    *)
        echo "⚙️ Configurando nodo general..."
        kubectl label node $NODE_NAME node-role.kubernetes.io/worker=true
        ;;
esac

echo "✅ Nodo configurado con rol: $NODE_ROLE"
```

---

## Alta Disponibilidad (HA)

### Configuración de Load Balancer

```bash
#!/bin/bash
# setup-haproxy-lb.sh - Ejecutar en nodos de load balancer

set -e

MASTER_NODES=("10.0.0.101" "10.0.0.102" "10.0.0.103")
LB_VIP="10.0.0.100"

echo "⚖️ Configurando HAProxy para k8s masters..."

# Instalar HAProxy y Keepalived
sudo apt-get update
sudo apt-get install -y haproxy keepalived

# Configurar HAProxy
cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg
global
    log stdout local0
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    mode http
    log global
    option httplog
    option dontlognull
    option log-health-checks
    option forwardfor except 127.0.0.0/8
    option redispatch
    retries 3
    timeout http-request 10s
    timeout queue 1m
    timeout connect 10s
    timeout client 300s
    timeout server 300s
    timeout http-keep-alive 10s
    timeout check 10s

# Stats page
listen stats
    bind *:8404
    stats enable
    stats uri /
    stats refresh 30s
    stats admin if TRUE

# Kubernetes API Server
frontend k8s-api-frontend
    bind *:6443
    mode tcp
    option tcplog
    default_backend k8s-api-backend

backend k8s-api-backend
    mode tcp
    balance roundrobin
    option tcp-check
EOF

# Agregar servidores master
for i in "${!MASTER_NODES[@]}"; do
    echo "    server k8s-master-$((i+1)) ${MASTER_NODES[$i]}:6443 check" | sudo tee -a /etc/haproxy/haproxy.cfg
done

# Configurar Keepalived para VIP
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
PRIORITY=$((100 + $(hostname | tail -c 2)))

cat <<EOF | sudo tee /etc/keepalived/keepalived.conf
! Configuration File for keepalived

global_defs {
   notification_email {
     admin@company.com
   }
   notification_email_from keepalived@$(hostname)
   smtp_server 127.0.0.1
   smtp_connect_timeout 30
   router_id $(hostname)
}

vrrp_script chk_haproxy {
    script "/bin/curl -f http://localhost:8404 || exit 1"
    interval 2
    weight -2
    fall 3
    rise 2
}

vrrp_instance VI_1 {
    state BACKUP
    interface $INTERFACE
    virtual_router_id 51
    priority $PRIORITY
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass k8s-ha-pass
    }
    virtual_ipaddress {
        $LB_VIP
    }
    track_script {
        chk_haproxy
    }
}
EOF

# Habilitar y iniciar servicios
sudo systemctl enable haproxy keepalived
sudo systemctl start haproxy keepalived

echo "✅ Load balancer configurado"
echo "🌐 VIP: $LB_VIP"
echo "📊 Stats: http://$LB_VIP:8404"
```

### Configuración de etcd Externo

```bash
#!/bin/bash
# setup-external-etcd.sh

set -e

ETCD_NODES=("etcd1.company.com" "etcd2.company.com" "etcd3.company.com")
ETCD_IPS=("10.0.0.201" "10.0.0.202" "10.0.0.203")
NODE_NAME=$(hostname)
NODE_IP=$(hostname -I | awk '{print $1}')

echo "🗄️ Configurando etcd externo en $NODE_NAME..."

# Crear usuario etcd
sudo useradd -r -s /bin/false etcd

# Crear directorios
sudo mkdir -p /etc/etcd /var/lib/etcd
sudo chown etcd:etcd /var/lib/etcd
sudo chmod 700 /var/lib/etcd

# Descargar etcd
ETCD_VERSION="v3.5.10"
wget https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz
tar xzf etcd-${ETCD_VERSION}-linux-amd64.tar.gz
sudo mv etcd-${ETCD_VERSION}-linux-amd64/etcd* /usr/local/bin/
rm -rf etcd-${ETCD_VERSION}-linux-amd64*

# Generar certificados
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes etcd-csr.json | cfssljson -bare etcd

# Mover certificados
sudo mv ca.pem ca-key.pem etcd.pem etcd-key.pem /etc/etcd/
sudo chown etcd:etcd /etc/etcd/*
sudo chmod 600 /etc/etcd/*-key.pem

# Configurar etcd
cat <<EOF | sudo tee /etc/etcd/etcd.conf
ETCD_NAME=$NODE_NAME
ETCD_DATA_DIR=/var/lib/etcd
ETCD_LISTEN_PEER_URLS=https://$NODE_IP:2380
ETCD_LISTEN_CLIENT_URLS=https://$NODE_IP:2379,https://127.0.0.1:2379
ETCD_ADVERTISE_CLIENT_URLS=https://$NODE_IP:2379
ETCD_INITIAL_ADVERTISE_PEER_URLS=https://$NODE_IP:2380
ETCD_INITIAL_CLUSTER=${ETCD_NODES[0]}=https://${ETCD_IPS[0]}:2380,${ETCD_NODES[1]}=https://${ETCD_IPS[1]}:2380,${ETCD_NODES[2]}=https://${ETCD_IPS[2]}:2380
ETCD_INITIAL_CLUSTER_STATE=new
ETCD_INITIAL_CLUSTER_TOKEN=etcd-cluster
ETCD_CLIENT_CERT_AUTH=true
ETCD_TRUSTED_CA_FILE=/etc/etcd/ca.pem
ETCD_CERT_FILE=/etc/etcd/etcd.pem
ETCD_KEY_FILE=/etc/etcd/etcd-key.pem
ETCD_PEER_CLIENT_CERT_AUTH=true
ETCD_PEER_TRUSTED_CA_FILE=/etc/etcd/ca.pem
ETCD_PEER_CERT_FILE=/etc/etcd/etcd.pem
ETCD_PEER_KEY_FILE=/etc/etcd/etcd-key.pem
EOF

# Crear servicio systemd
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/etcd-io/etcd
Conflicts=etcd-member.service
After=network.target

[Service]
Type=notify
User=etcd
EnvironmentFile=/etc/etcd/etcd.conf
ExecStart=/usr/local/bin/etcd
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

echo "✅ etcd configurado"
echo "🔍 Verificar con: etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/etcd.pem --key=/etc/etcd/etcd-key.pem endpoint health"
```

---

## Networking (CNI)

### Instalación de Calico

```bash
#!/bin/bash
# install-calico.sh

set -e

echo "🔗 Instalando Calico CNI..."

# Descargar manifiestos de Calico
curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/tigera-operator.yaml -O
curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/custom-resources.yaml -O

# Aplicar operador
kubectl apply -f tigera-operator.yaml

# Configurar Calico
cat <<EOF > calico-config.yaml
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
  nodeAddressAutodetectionV4:
    interface: "eth0"
  registry: quay.io
---
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
EOF

kubectl apply -f calico-config.yaml

# Esperar a que Calico esté listo
echo "⏳ Esperando a que Calico esté listo..."
kubectl wait --for=condition=Ready pods -l k8s-app=calico-node -n calico-system --timeout=300s

echo "✅ Calico instalado y configurado"
```

### Configuración Avanzada de Calico

```yaml
# calico-advanced-config.yaml
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  variant: Calico
  registry: quay.io
  calicoNetwork:
    bgp: Enabled
    ipPools:
    - blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: IPIP
      natOutgoing: Enabled
      nodeSelector: all()
    - blockSize: 26
      cidr: 172.16.0.0/16
      encapsulation: None
      natOutgoing: Enabled
      nodeSelector: rack == "rack-1"
    nodeAddressAutodetectionV4:
      interface: "eth0"
    nodeAddressAutodetectionV6:
      interface: "eth0"
    multiInterfaceMode: None
  kubeletVolumePluginPath: /var/lib/kubelet
  flexVolumePath: /usr/libexec/kubernetes/kubelet-plugins/volume/exec/
  nodeUpdateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  componentResources:
  - componentName: Node
    resourceRequirements:
      requests:
        cpu: 250m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
  - componentName: Typha
    resourceRequirements:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 300m
        memory: 256Mi
---
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  logSeverityScreen: Info
  nodeToNodeMeshEnabled: true
  asNumber: 64512
---
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: production-pool
spec:
  cidr: 10.244.0.0/16
  blockSize: 26
  ipipMode: CrossSubnet
  natOutgoing: true
  disabled: false
  nodeSelector: environment == "production"
```

### Network Policies

```yaml
# network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web-to-api
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: web
    ports:
    - protocol: TCP
      port: 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-database
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: api
    ports:
    - protocol: TCP
      port: 5432
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    - podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

---

## Storage

### Configuración de Longhorn

```bash
#!/bin/bash
# install-longhorn.sh

set -e

echo "🐄 Instalando Longhorn para storage distribuido..."

# Prerequisitos
echo "📋 Verificando prerequisitos..."
sudo apt-get update
sudo apt-get install -y open-iscsi nfs-common

# Instalar Longhorn
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/longhorn.yaml

# Esperar a que esté listo
echo "⏳ Esperando a que Longhorn esté listo..."
kubectl -n longhorn-system rollout status deployment/longhorn-manager --timeout=600s
kubectl -n longhorn-system rollout status deployment/longhorn-driver-deployer --timeout=600s

# Configurar como StorageClass por defecto
kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Crear Ingress para UI
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn-ui
  namespace: longhorn-system
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: longhorn-auth
spec:
  rules:
  - host: longhorn.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: longhorn-frontend
            port:
              number: 80
EOF

# Crear autenticación básica
htpasswd -c auth admin
kubectl -n longhorn-system create secret generic longhorn-auth --from-file=auth

echo "✅ Longhorn instalado"
echo "🌐 UI disponible en: https://longhorn.company.com"
```

### Configuración de CSI para múltiples proveedores

```yaml
# storage-classes.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "2880"
  fromBackup: ""
  fsType: "ext4"
  diskSelector: "ssd"
  nodeSelector: "storage-tier,fast"
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: bulk-storage
provisioner: longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
parameters:
  numberOfReplicas: "2"
  staleReplicaTimeout: "2880"
  fromBackup: ""
  fsType: "ext4"
  diskSelector: "hdd"
  nodeSelector: "storage-tier,bulk"
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: backup-storage
provisioner: longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
parameters:
  numberOfReplicas: "1"
  staleReplicaTimeout: "2880"
  fromBackup: ""
  fsType: "ext4"
  recurringJobSelector: '[
    {
      "name": "backup",
      "isGroup": false
    }
  ]'
---
# NFS StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-shared
provisioner: nfs.csi.k8s.io
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
parameters:
  server: nfs.company.com
  share: /exports/k8s
mountOptions:
  - nfsvers=4.1
  - hard
  - timeo=600
  - retrans=2
```

---

## Seguridad

### Configuración de Pod Security Standards

```yaml
# pod-security-policies.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secure-namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
  seccompProfile:
    type: 'RuntimeDefault'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: restricted-psp-user
rules:
- apiGroups: ['policy']
  resources: ['podsecuritypolicies']
  verbs: ['use']
  resourceNames:
  - restricted-psp
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: restricted-psp-all-users
roleRef:
  kind: ClusterRole
  name: restricted-psp-user
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: Group
  name: system:authenticated
  apiGroup: rbac.authorization.k8s.io
```

### RBAC Avanzado

```yaml
# rbac-roles.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]
  verbs: ["get", "list", "create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: readonly
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: production-operator
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "patch"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: production-operators
  namespace: production
subjects:
- kind: User
  name: ops-team@company.com
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: production-operator
  apiGroup: rbac.authorization.k8s.io
```

### Configuración de OPA Gatekeeper

```bash
#!/bin/bash
# install-gatekeeper.sh

set -e

echo "🛡️ Instalando OPA Gatekeeper..."

# Instalar Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

# Esperar a que esté listo
kubectl wait --for=condition=Ready pods -l control-plane=controller-manager -n gatekeeper-system --timeout=300s

echo "✅ Gatekeeper instalado"
```

```yaml
# gatekeeper-policies.yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        
        violation[{"msg": msg}] {
          required := input.parameters.labels
          provided := input.review.object.metadata.labels
          missing := required[_]
          not provided[missing]
          msg := sprintf("Missing required label: %v", [missing])
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: namespace-must-have-environment
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Namespace"]
  parameters:
    labels: ["environment", "team", "cost-center"]
---
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8scontainerlimits
spec:
  crd:
    spec:
      names:
        kind: K8sContainerLimits
      validation:
        openAPIV3Schema:
          type: object
          properties:
            cpu:
              type: string
            memory:
              type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8scontainerlimits
        
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.limits.cpu
          msg := "Container missing CPU limits"
        }
        
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.limits.memory
          msg := "Container missing memory limits"
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sContainerLimits
metadata:
  name: containers-must-have-limits
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment", "StatefulSet", "DaemonSet"]
  parameters:
    cpu: "1000m"
    memory: "1Gi"
```

Este setup avanzado de kubeadm proporciona una base sólida para clusters de producción con todas las características empresariales necesarias: alta disponibilidad, seguridad robusta, networking avanzado, y almacenamiento distribuido.
