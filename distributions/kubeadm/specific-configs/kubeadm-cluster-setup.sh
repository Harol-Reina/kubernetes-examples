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
