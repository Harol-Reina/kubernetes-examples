#!/bin/bash
# Deploy Kubernetes Cluster with Kubespray
# Uso: ./deploy-cluster.sh [production|development|testing]

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Variables por defecto
CLUSTER_TYPE="${1:-production}"
KUBESPRAY_DIR="${KUBESPRAY_DIR:-./kubespray}"
INVENTORY_DIR="${KUBESPRAY_DIR}/inventory/mycluster"
CONFIG_DIR="./specific-configs"

# Función para verificar prerrequisitos
check_prerequisites() {
    log_info "Verificando prerrequisitos..."
    
    # Verificar Ansible
    if ! command -v ansible &> /dev/null; then
        log_error "Ansible no está instalado. Instálalo con: pip3 install ansible"
        exit 1
    fi
    
    # Verificar Kubespray
    if [ ! -d "$KUBESPRAY_DIR" ]; then
        log_error "Directorio de Kubespray no encontrado en $KUBESPRAY_DIR"
        log_info "Clona Kubespray con: git clone https://github.com/kubernetes-sigs/kubespray.git"
        exit 1
    fi
    
    # Verificar dependencias de Python
    if [ -f "$KUBESPRAY_DIR/requirements.txt" ]; then
        log_info "Instalando dependencias de Python..."
        pip3 install -r "$KUBESPRAY_DIR/requirements.txt"
    fi
    
    log_success "Prerrequisitos verificados"
}

# Función para configurar inventario
setup_inventory() {
    log_info "Configurando inventario para cluster tipo: $CLUSTER_TYPE"
    
    # Crear directorio de inventario si no existe
    mkdir -p "$INVENTORY_DIR"
    
    # Copiar configuración base
    if [ ! -f "$INVENTORY_DIR/hosts.yaml" ]; then
        case $CLUSTER_TYPE in
            "production")
                cp "$CONFIG_DIR/inventory/hosts-ha.yaml" "$INVENTORY_DIR/hosts.yaml"
                ;;
            "development"|"testing")
                cp "$CONFIG_DIR/inventory/hosts-single-master.yaml" "$INVENTORY_DIR/hosts.yaml"
                ;;
            *)
                log_error "Tipo de cluster no válido: $CLUSTER_TYPE"
                log_info "Tipos válidos: production, development, testing"
                exit 1
                ;;
        esac
    fi
    
    # Copiar group_vars
    mkdir -p "$INVENTORY_DIR/group_vars"
    cp -r "$CONFIG_DIR/group_vars/"* "$INVENTORY_DIR/group_vars/"
    
    log_success "Inventario configurado"
}

# Función para validar conectividad
validate_connectivity() {
    log_info "Validando conectividad SSH con los nodos..."
    
    if ansible all -i "$INVENTORY_DIR/hosts.yaml" -m ping; then
        log_success "Conectividad SSH validada"
    else
        log_error "Error de conectividad SSH. Verifica:"
        log_info "1. Las IPs en el inventario son correctas"
        log_info "2. Tienes acceso SSH a todos los nodos"
        log_info "3. El usuario tiene privilegios sudo"
        exit 1
    fi
}

# Función para desplegar cluster
deploy_cluster() {
    log_info "Iniciando despliegue del cluster Kubernetes..."
    
    # Cambiar al directorio de Kubespray
    cd "$KUBESPRAY_DIR"
    
    # Ejecutar playbook principal
    log_info "Ejecutando playbook cluster.yml..."
    if ansible-playbook -i "$INVENTORY_DIR/hosts.yaml" \
        --become --become-user=root \
        cluster.yml; then
        log_success "Cluster desplegado exitosamente!"
    else
        log_error "Error durante el despliegue del cluster"
        exit 1
    fi
    
    # Volver al directorio original
    cd - > /dev/null
}

# Función para configurar kubectl
setup_kubectl() {
    log_info "Configurando kubectl..."
    
    # Obtener kubeconfig del master
    MASTER_IP=$(ansible-inventory -i "$INVENTORY_DIR/hosts.yaml" --list | \
        jq -r '.kube_control_plane.hosts[0]')
    
    if [ "$MASTER_IP" != "null" ]; then
        # Crear directorio .kube si no existe
        mkdir -p ~/.kube
        
        # Copiar kubeconfig desde el master
        ansible -i "$INVENTORY_DIR/hosts.yaml" "$MASTER_IP" \
            -m fetch \
            -a "src=/etc/kubernetes/admin.conf dest=~/.kube/config flat=yes" \
            --become
        
        # Ajustar permisos
        chmod 600 ~/.kube/config
        
        log_success "kubectl configurado"
    else
        log_warning "No se pudo determinar la IP del master para configurar kubectl"
    fi
}

# Función para verificar cluster
verify_cluster() {
    log_info "Verificando estado del cluster..."
    
    # Verificar nodos
    log_info "Nodos del cluster:"
    kubectl get nodes -o wide
    
    # Verificar pods del sistema
    log_info "Pods del sistema:"
    kubectl get pods --all-namespaces
    
    # Verificar servicios
    log_info "Servicios:"
    kubectl get services --all-namespaces
    
    log_success "Cluster verificado - ¡Listo para usar!"
}

# Función para mostrar información post-instalación
show_post_install_info() {
    log_info "=== INFORMACIÓN POST-INSTALACIÓN ==="
    
    echo ""
    log_info "Dashboard de Kubernetes:"
    echo "  kubectl proxy"
    echo "  http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
    
    echo ""
    log_info "Comandos útiles:"
    echo "  kubectl get nodes"
    echo "  kubectl get pods --all-namespaces"
    echo "  kubectl cluster-info"
    
    echo ""
    log_info "Para acceder desde otro equipo:"
    echo "  Copia el archivo ~/.kube/config a tu máquina local"
    
    echo ""
    log_success "¡Cluster desplegado exitosamente!"
}

# Función principal
main() {
    log_info "=== KUBESPRAY CLUSTER DEPLOYMENT ==="
    log_info "Tipo de cluster: $CLUSTER_TYPE"
    
    check_prerequisites
    setup_inventory
    validate_connectivity
    deploy_cluster
    setup_kubectl
    verify_cluster
    show_post_install_info
}

# Función de ayuda
show_help() {
    echo "Uso: $0 [TIPO_CLUSTER]"
    echo ""
    echo "TIPO_CLUSTER:"
    echo "  production   - Cluster HA con 3 masters + workers (por defecto)"
    echo "  development  - Cluster simple con 1 master + workers"
    echo "  testing      - Cluster mínimo para pruebas"
    echo ""
    echo "Variables de entorno:"
    echo "  KUBESPRAY_DIR - Directorio donde está clonado Kubespray (por defecto: ./kubespray)"
    echo ""
    echo "Ejemplos:"
    echo "  $0 production"
    echo "  $0 development"
    echo "  KUBESPRAY_DIR=/opt/kubespray $0 testing"
}

# Verificar argumentos
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    show_help
    exit 0
fi

# Ejecutar función principal
main "$@"
