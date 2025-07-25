#!/bin/bash
# Upgrade Kubernetes Cluster with Kubespray
# Uso: ./upgrade-cluster.sh [VERSION]

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

# Variables
TARGET_VERSION="${1:-}"
KUBESPRAY_DIR="${KUBESPRAY_DIR:-./kubespray}"
INVENTORY_DIR="${KUBESPRAY_DIR}/inventory/mycluster"
BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [VERSION]"
    echo ""
    echo "VERSION: Versión de Kubernetes a la que actualizar (ej: v1.28.8)"
    echo ""
    echo "Ejemplos:"
    echo "  $0 v1.28.8"
    echo "  $0 v1.29.0"
    echo ""
    echo "Variables de entorno:"
    echo "  KUBESPRAY_DIR - Directorio de Kubespray (por defecto: ./kubespray)"
}

# Función para verificar prerrequisitos
check_prerequisites() {
    log_info "Verificando prerrequisitos para upgrade..."
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl no está instalado"
        exit 1
    fi
    
    # Verificar conectividad al cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "No se puede conectar al cluster. Verifica kubeconfig"
        exit 1
    fi
    
    # Verificar Kubespray
    if [ ! -d "$KUBESPRAY_DIR" ]; then
        log_error "Directorio de Kubespray no encontrado en $KUBESPRAY_DIR"
        exit 1
    fi
    
    # Verificar inventario
    if [ ! -f "$INVENTORY_DIR/hosts.yaml" ]; then
        log_error "Archivo de inventario no encontrado: $INVENTORY_DIR/hosts.yaml"
        exit 1
    fi
    
    log_success "Prerrequisitos verificados"
}

# Función para obtener versión actual
get_current_version() {
    CURRENT_VERSION=$(kubectl version --short --client=false -o json | jq -r '.serverVersion.gitVersion')
    log_info "Versión actual del cluster: $CURRENT_VERSION"
}

# Función para validar versión objetivo
validate_target_version() {
    if [ -z "$TARGET_VERSION" ]; then
        log_error "Debe especificar la versión objetivo"
        show_help
        exit 1
    fi
    
    log_info "Versión objetivo: $TARGET_VERSION"
    
    # Verificar que la versión objetivo es válida
    if ! echo "$TARGET_VERSION" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
        log_error "Formato de versión inválido. Use formato vX.Y.Z (ej: v1.28.8)"
        exit 1
    fi
}

# Función para backup del cluster
backup_cluster() {
    log_info "Creando backup del cluster..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup de configuración de kubectl
    cp ~/.kube/config "$BACKUP_DIR/kubeconfig-backup"
    
    # Backup de recursos del cluster
    log_info "Backup de recursos..."
    kubectl get all --all-namespaces -o yaml > "$BACKUP_DIR/all-resources.yaml"
    kubectl get pv -o yaml > "$BACKUP_DIR/persistent-volumes.yaml"
    kubectl get pvc --all-namespaces -o yaml > "$BACKUP_DIR/persistent-volume-claims.yaml"
    kubectl get configmaps --all-namespaces -o yaml > "$BACKUP_DIR/configmaps.yaml"
    kubectl get secrets --all-namespaces -o yaml > "$BACKUP_DIR/secrets.yaml"
    
    # Backup de CRDs
    kubectl get crd -o yaml > "$BACKUP_DIR/custom-resource-definitions.yaml"
    
    # Backup de RBAC
    kubectl get clusterroles -o yaml > "$BACKUP_DIR/clusterroles.yaml"
    kubectl get clusterrolebindings -o yaml > "$BACKUP_DIR/clusterrolebindings.yaml"
    kubectl get roles --all-namespaces -o yaml > "$BACKUP_DIR/roles.yaml"
    kubectl get rolebindings --all-namespaces -o yaml > "$BACKUP_DIR/rolebindings.yaml"
    
    log_success "Backup completado en: $BACKUP_DIR"
}

# Función para verificar estado del cluster antes del upgrade
pre_upgrade_checks() {
    log_info "Verificaciones pre-upgrade..."
    
    # Verificar que todos los nodos están listos
    NOT_READY_NODES=$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l)
    if [ "$NOT_READY_NODES" -gt 0 ]; then
        log_error "Hay $NOT_READY_NODES nodos no listos. Corrígelos antes del upgrade."
        kubectl get nodes
        exit 1
    fi
    
    # Verificar pods en estado problemático
    PROBLEMATIC_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers | wc -l)
    if [ "$PROBLEMATIC_PODS" -gt 0 ]; then
        log_warning "Hay $PROBLEMATIC_PODS pods en estado problemático:"
        kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded
        
        read -p "¿Continuar con el upgrade? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Upgrade cancelado por el usuario"
            exit 0
        fi
    fi
    
    # Verificar espacio en disco en nodos
    log_info "Verificando espacio en disco en nodos..."
    ansible all -i "$INVENTORY_DIR/hosts.yaml" -m shell -a "df -h / | tail -1"
    
    log_success "Verificaciones pre-upgrade completadas"
}

# Función para actualizar configuración de Kubespray
update_kubespray_config() {
    log_info "Actualizando configuración de Kubespray..."
    
    # Actualizar versión en group_vars
    K8S_CONFIG="$INVENTORY_DIR/group_vars/k8s_cluster/k8s-cluster.yml"
    
    if [ -f "$K8S_CONFIG" ]; then
        # Backup de la configuración actual
        cp "$K8S_CONFIG" "$BACKUP_DIR/k8s-cluster.yml.bak"
        
        # Actualizar versión de Kubernetes
        sed -i "s/kube_version: .*/kube_version: $TARGET_VERSION/" "$K8S_CONFIG"
        
        log_info "Configuración actualizada en $K8S_CONFIG"
    else
        log_warning "Archivo de configuración no encontrado: $K8S_CONFIG"
    fi
}

# Función para ejecutar el upgrade
perform_upgrade() {
    log_info "Iniciando upgrade del cluster..."
    
    cd "$KUBESPRAY_DIR"
    
    # Ejecutar playbook de upgrade
    log_info "Ejecutando playbook upgrade-cluster.yml..."
    if ansible-playbook -i "$INVENTORY_DIR/hosts.yaml" \
        --become --become-user=root \
        upgrade-cluster.yml \
        -e kube_version="$TARGET_VERSION"; then
        log_success "Upgrade completado exitosamente!"
    else
        log_error "Error durante el upgrade del cluster"
        log_info "Revisa los logs y considera restaurar desde backup si es necesario"
        exit 1
    fi
    
    cd - > /dev/null
}

# Función para verificar el upgrade
verify_upgrade() {
    log_info "Verificando upgrade..."
    
    # Esperar a que el cluster esté listo
    log_info "Esperando a que el cluster esté listo..."
    sleep 30
    
    # Verificar versión de los nodos
    log_info "Versiones de los nodos:"
    kubectl get nodes -o wide
    
    # Verificar versión del servidor
    NEW_VERSION=$(kubectl version --short --client=false -o json | jq -r '.serverVersion.gitVersion')
    log_info "Nueva versión del cluster: $NEW_VERSION"
    
    if [ "$NEW_VERSION" = "$TARGET_VERSION" ]; then
        log_success "Upgrade verificado - Versión actualizada correctamente"
    else
        log_error "Upgrade falló - Versión esperada: $TARGET_VERSION, versión actual: $NEW_VERSION"
        exit 1
    fi
    
    # Verificar que todos los pods del sistema estén funcionando
    log_info "Verificando pods del sistema..."
    kubectl get pods --all-namespaces
    
    # Verificar componentes críticos
    CRITICAL_NAMESPACES=("kube-system" "kube-public")
    for ns in "${CRITICAL_NAMESPACES[@]}"; do
        FAILED_PODS=$(kubectl get pods -n "$ns" --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers | wc -l)
        if [ "$FAILED_PODS" -gt 0 ]; then
            log_warning "Hay $FAILED_PODS pods fallidos en namespace $ns"
            kubectl get pods -n "$ns" --field-selector=status.phase!=Running,status.phase!=Succeeded
        fi
    done
    
    log_success "Verificación del upgrade completada"
}

# Función para mostrar información post-upgrade
show_post_upgrade_info() {
    log_info "=== INFORMACIÓN POST-UPGRADE ==="
    
    echo ""
    log_info "Upgrade completado:"
    echo "  Versión anterior: $CURRENT_VERSION"
    echo "  Versión actual:   $NEW_VERSION"
    
    echo ""
    log_info "Backup guardado en: $BACKUP_DIR"
    
    echo ""
    log_info "Comandos de verificación:"
    echo "  kubectl get nodes"
    echo "  kubectl get pods --all-namespaces"
    echo "  kubectl cluster-info"
    
    echo ""
    log_success "¡Upgrade completado exitosamente!"
}

# Función principal
main() {
    log_info "=== KUBESPRAY CLUSTER UPGRADE ==="
    
    check_prerequisites
    get_current_version
    validate_target_version
    
    # Confirmar el upgrade
    echo ""
    log_warning "¿Estás seguro de que quieres actualizar el cluster?"
    log_info "Versión actual: $CURRENT_VERSION"
    log_info "Versión objetivo: $TARGET_VERSION"
    echo ""
    read -p "Continuar con el upgrade? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Upgrade cancelado por el usuario"
        exit 0
    fi
    
    backup_cluster
    pre_upgrade_checks
    update_kubespray_config
    perform_upgrade
    verify_upgrade
    show_post_upgrade_info
}

# Verificar argumentos
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    show_help
    exit 0
fi

# Ejecutar función principal
main "$@"
