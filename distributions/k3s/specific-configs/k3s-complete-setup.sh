#!/bin/bash
# k3s-complete-setup.sh

set -e

# Configuración
K3S_VERSION="${K3S_VERSION:-v1.28.2+k3s1}"
CLUSTER_NAME="${CLUSTER_NAME:-k3s-cluster}"
INSTALL_MONITORING="${INSTALL_MONITORING:-true}"
INSTALL_INGRESS="${INSTALL_INGRESS:-true}"

echo "🚀 Setting up complete k3s cluster: $CLUSTER_NAME"

# Función para instalar k3s
install_k3s() {
    echo "Installing k3s..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION sh -s - \
        --write-kubeconfig-mode=644 \
        --disable=traefik \
        --disable=servicelb \
        --node-name=$CLUSTER_NAME-master
    
    # Configurar kubectl
    mkdir -p ~/.kube
    cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    chmod 600 ~/.kube/config
    
    echo "✅ k3s installed successfully!"
}

# Función para instalar Helm
install_helm() {
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    # Agregar repositorios
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    echo "✅ Helm installed successfully!"
}

# Función para instalar NGINX Ingress
install_nginx_ingress() {
    if [ "$INSTALL_INGRESS" = "true" ]; then
        echo "Installing NGINX Ingress Controller..."
        helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
            --namespace ingress-nginx \
            --create-namespace \
            --set controller.service.type=LoadBalancer \
            --wait
        
        echo "✅ NGINX Ingress installed successfully!"
    fi
}

# Función para instalar monitoreo
install_monitoring() {
    if [ "$INSTALL_MONITORING" = "true" ]; then
        echo "Installing monitoring stack..."
        kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
        
        helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
            --namespace monitoring \
            --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=local-path \
            --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
            --set grafana.persistence.enabled=true \
            --set grafana.persistence.storageClassName=local-path \
            --set grafana.adminPassword=admin123 \
            --wait
        
        echo "✅ Monitoring stack installed successfully!"
        echo "Grafana password: admin123"
    fi
}

# Función principal
main() {
    echo "Starting k3s setup..."
    
    install_k3s
    sleep 10  # Esperar a que k3s esté listo
    
    install_helm
    install_nginx_ingress
    install_monitoring
    
    echo ""
    echo "🎉 k3s cluster setup completed!"
    echo ""
    echo "Cluster info:"
    kubectl cluster-info
    echo ""
    echo "Nodes:"
    kubectl get nodes
    echo ""
    echo "Services:"
    kubectl get svc --all-namespaces
}

# Ejecutar instalación
main
