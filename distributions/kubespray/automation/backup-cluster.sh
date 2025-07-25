#!/bin/bash
# Backup Kubernetes Cluster with Kubespray
# Uso: ./backup-cluster.sh [full|etcd|resources]

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
BACKUP_TYPE="${1:-full}"
BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
KUBESPRAY_DIR="${KUBESPRAY_DIR:-./kubespray}"
INVENTORY_DIR="${KUBESPRAY_DIR}/inventory/mycluster"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [TIPO_BACKUP]"
    echo ""
    echo "TIPOS DE BACKUP:"
    echo "  full      - Backup completo (etcd + recursos + configuración)"
    echo "  etcd      - Solo backup de etcd"
    echo "  resources - Solo backup de recursos de Kubernetes"
    echo ""
    echo "Ejemplos:"
    echo "  $0 full       # Backup completo"
    echo "  $0 etcd       # Solo etcd"
    echo "  $0 resources  # Solo recursos"
    echo ""
    echo "Variables de entorno:"
    echo "  KUBESPRAY_DIR    - Directorio de Kubespray (por defecto: ./kubespray)"
    echo "  RETENTION_DAYS   - Días de retención de backups (por defecto: 7)"
}

# Función para verificar prerrequisitos
check_prerequisites() {
    log_info "Verificando prerrequisitos..."
    
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
    
    # Verificar Ansible si es backup de etcd
    if [ "$BACKUP_TYPE" = "full" ] || [ "$BACKUP_TYPE" = "etcd" ]; then
        if ! command -v ansible &> /dev/null; then
            log_error "Ansible no está instalado (requerido para backup de etcd)"
            exit 1
        fi
        
        if [ ! -f "$INVENTORY_DIR/hosts.yaml" ]; then
            log_error "Archivo de inventario no encontrado: $INVENTORY_DIR/hosts.yaml"
            exit 1
        fi
    fi
    
    # Crear directorio de backup
    mkdir -p "$BACKUP_DIR"
    
    log_success "Prerrequisitos verificados"
}

# Función para backup de etcd
backup_etcd() {
    log_info "Iniciando backup de etcd..."
    
    # Obtener información del cluster etcd
    ETCD_ENDPOINTS=$(kubectl get endpoints etcd -n kube-system -o jsonpath='{.subsets[*].addresses[*].ip}' | tr ' ' ',')
    
    if [ -z "$ETCD_ENDPOINTS" ]; then
        log_warning "No se pudieron detectar endpoints de etcd desde k8s API"
        log_info "Usando inventario de Ansible para encontrar nodos etcd..."
    fi
    
    # Backup usando Ansible en nodos etcd
    cd "$KUBESPRAY_DIR"
    
    # Script de backup para ejecutar en nodos etcd
    cat > /tmp/etcd-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/tmp/etcd-backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Detectar version de etcd y paths
ETCD_VERSION=$(etcdctl version | head -1 | cut -d' ' -f3)
ETCD_DATA_DIR="/var/lib/etcd"

# Configurar variables de entorno para etcdctl
export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS="https://127.0.0.1:2379"
export ETCDCTL_CACERT="/etc/ssl/etcd/ssl/ca.pem"
export ETCDCTL_CERT="/etc/ssl/etcd/ssl/member-$(hostname).pem"
export ETCDCTL_KEY="/etc/ssl/etcd/ssl/member-$(hostname)-key.pem"

# Verificar salud de etcd
if etcdctl endpoint health; then
    echo "etcd está saludable, procediendo con backup..."
    
    # Hacer snapshot
    etcdctl snapshot save "$BACKUP_DIR/etcd-snapshot.db"
    
    # Verificar snapshot
    etcdctl snapshot status "$BACKUP_DIR/etcd-snapshot.db" -w table
    
    # Backup de certificados y configuración
    cp -r /etc/ssl/etcd "$BACKUP_DIR/"
    cp -r /etc/etcd.env "$BACKUP_DIR/" 2>/dev/null || true
    
    # Comprimir backup
    tar -czf "/tmp/etcd-backup-$(hostname)-$(date +%Y%m%d_%H%M%S).tar.gz" -C "$BACKUP_DIR" .
    
    echo "Backup de etcd completado: /tmp/etcd-backup-$(hostname)-$(date +%Y%m%d_%H%M%S).tar.gz"
    ls -la /tmp/etcd-backup-*.tar.gz
else
    echo "ERROR: etcd no está saludable"
    exit 1
fi
EOF
    
    # Copiar script a nodos etcd y ejecutar
    ansible etcd -i "$INVENTORY_DIR/hosts.yaml" -m copy -a "src=/tmp/etcd-backup.sh dest=/tmp/etcd-backup.sh mode=0755" --become
    ansible etcd -i "$INVENTORY_DIR/hosts.yaml" -m shell -a "/tmp/etcd-backup.sh" --become
    
    # Descargar backups de etcd
    log_info "Descargando backups de etcd..."
    ansible etcd -i "$INVENTORY_DIR/hosts.yaml" -m fetch -a "src=/tmp/etcd-backup-*.tar.gz dest=$BACKUP_DIR/etcd/ flat=no" --become
    
    # Limpiar archivos temporales
    ansible etcd -i "$INVENTORY_DIR/hosts.yaml" -m shell -a "rm -f /tmp/etcd-backup.sh /tmp/etcd-backup-*.tar.gz" --become
    rm -f /tmp/etcd-backup.sh
    
    cd - > /dev/null
    
    log_success "Backup de etcd completado"
}

# Función para backup de recursos de Kubernetes
backup_resources() {
    log_info "Iniciando backup de recursos de Kubernetes..."
    
    local RESOURCES_DIR="$BACKUP_DIR/k8s-resources"
    mkdir -p "$RESOURCES_DIR"
    
    # Backup de información del cluster
    kubectl cluster-info > "$RESOURCES_DIR/cluster-info.txt"
    kubectl version -o yaml > "$RESOURCES_DIR/cluster-version.yaml"
    kubectl get nodes -o yaml > "$RESOURCES_DIR/nodes.yaml"
    
    # Backup de todos los recursos por namespace
    log_info "Backup de recursos por namespace..."
    kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' > "$RESOURCES_DIR/namespaces.txt"
    
    while IFS= read -r ns; do
        if [ -n "$ns" ]; then
            log_info "Backup de namespace: $ns"
            mkdir -p "$RESOURCES_DIR/namespaces/$ns"
            
            # Recursos con namespace
            kubectl get all -n "$ns" -o yaml > "$RESOURCES_DIR/namespaces/$ns/all.yaml" 2>/dev/null || true
            kubectl get configmaps -n "$ns" -o yaml > "$RESOURCES_DIR/namespaces/$ns/configmaps.yaml" 2>/dev/null || true
            kubectl get secrets -n "$ns" -o yaml > "$RESOURCES_DIR/namespaces/$ns/secrets.yaml" 2>/dev/null || true
            kubectl get pvc -n "$ns" -o yaml > "$RESOURCES_DIR/namespaces/$ns/pvc.yaml" 2>/dev/null || true
            kubectl get networkpolicies -n "$ns" -o yaml > "$RESOURCES_DIR/namespaces/$ns/networkpolicies.yaml" 2>/dev/null || true
            kubectl get serviceaccounts -n "$ns" -o yaml > "$RESOURCES_DIR/namespaces/$ns/serviceaccounts.yaml" 2>/dev/null || true
            kubectl get roles -n "$ns" -o yaml > "$RESOURCES_DIR/namespaces/$ns/roles.yaml" 2>/dev/null || true
            kubectl get rolebindings -n "$ns" -o yaml > "$RESOURCES_DIR/namespaces/$ns/rolebindings.yaml" 2>/dev/null || true
        fi
    done < "$RESOURCES_DIR/namespaces.txt"
    
    # Recursos cluster-wide
    log_info "Backup de recursos cluster-wide..."
    mkdir -p "$RESOURCES_DIR/cluster-wide"
    
    kubectl get pv -o yaml > "$RESOURCES_DIR/cluster-wide/persistent-volumes.yaml" 2>/dev/null || true
    kubectl get storageclasses -o yaml > "$RESOURCES_DIR/cluster-wide/storageclasses.yaml" 2>/dev/null || true
    kubectl get clusterroles -o yaml > "$RESOURCES_DIR/cluster-wide/clusterroles.yaml" 2>/dev/null || true
    kubectl get clusterrolebindings -o yaml > "$RESOURCES_DIR/cluster-wide/clusterrolebindings.yaml" 2>/dev/null || true
    kubectl get crd -o yaml > "$RESOURCES_DIR/cluster-wide/crds.yaml" 2>/dev/null || true
    kubectl get validatingadmissionwebhooks -o yaml > "$RESOURCES_DIR/cluster-wide/validating-webhooks.yaml" 2>/dev/null || true
    kubectl get mutatingadmissionwebhooks -o yaml > "$RESOURCES_DIR/cluster-wide/mutating-webhooks.yaml" 2>/dev/null || true
    kubectl get priorityclasses -o yaml > "$RESOURCES_DIR/cluster-wide/priorityclasses.yaml" 2>/dev/null || true
    
    # Backup de configuración de red
    kubectl get ingressclasses -o yaml > "$RESOURCES_DIR/cluster-wide/ingressclasses.yaml" 2>/dev/null || true
    
    # Backup de métricas (si está disponible)
    if kubectl get --raw="/metrics" > /dev/null 2>&1; then
        kubectl get --raw="/metrics" > "$RESOURCES_DIR/cluster-metrics.txt"
    fi
    
    log_success "Backup de recursos de Kubernetes completado"
}

# Función para backup de configuración
backup_configuration() {
    log_info "Iniciando backup de configuración..."
    
    local CONFIG_DIR="$BACKUP_DIR/configuration"
    mkdir -p "$CONFIG_DIR"
    
    # Backup de kubeconfig
    if [ -f ~/.kube/config ]; then
        cp ~/.kube/config "$CONFIG_DIR/kubeconfig"
    fi
    
    # Backup de configuración de Kubespray
    if [ -d "$INVENTORY_DIR" ]; then
        cp -r "$INVENTORY_DIR" "$CONFIG_DIR/kubespray-inventory"
    fi
    
    # Backup de configuración adicional
    if [ -d "./specific-configs" ]; then
        cp -r "./specific-configs" "$CONFIG_DIR/"
    fi
    
    log_success "Backup de configuración completado"
}

# Función para comprimir backup
compress_backup() {
    log_info "Comprimiendo backup..."
    
    cd "$(dirname "$BACKUP_DIR")"
    BACKUP_NAME="$(basename "$BACKUP_DIR")"
    
    tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
    
    if [ -f "${BACKUP_NAME}.tar.gz" ]; then
        BACKUP_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
        log_success "Backup comprimido: ${BACKUP_NAME}.tar.gz ($BACKUP_SIZE)"
        
        # Remover directorio descomprimido
        rm -rf "$BACKUP_NAME"
        
        cd - > /dev/null
        echo "${PWD}/$(dirname "$BACKUP_DIR")/${BACKUP_NAME}.tar.gz"
    else
        log_error "Error al comprimir backup"
        cd - > /dev/null
        exit 1
    fi
}

# Función para limpiar backups antiguos
cleanup_old_backups() {
    log_info "Limpiando backups antiguos (más de $RETENTION_DAYS días)..."
    
    local BACKUP_BASE_DIR="$(dirname "$BACKUP_DIR")"
    
    if [ -d "$BACKUP_BASE_DIR" ]; then
        find "$BACKUP_BASE_DIR" -name "*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete
        find "$BACKUP_BASE_DIR" -type d -empty -delete
        
        local REMAINING_BACKUPS=$(find "$BACKUP_BASE_DIR" -name "*.tar.gz" -type f | wc -l)
        log_info "Backups restantes: $REMAINING_BACKUPS"
    fi
}

# Función para validar backup
validate_backup() {
    log_info "Validando backup..."
    
    local BACKUP_FILE="$1"
    
    if [ -f "$BACKUP_FILE" ]; then
        # Verificar que el archivo no está corrupto
        if tar -tzf "$BACKUP_FILE" > /dev/null 2>&1; then
            log_success "Backup válido: $BACKUP_FILE"
            
            # Mostrar contenido del backup
            log_info "Contenido del backup:"
            tar -tzf "$BACKUP_FILE" | head -20
            if [ $(tar -tzf "$BACKUP_FILE" | wc -l) -gt 20 ]; then
                echo "... y $(( $(tar -tzf "$BACKUP_FILE" | wc -l) - 20 )) archivos más"
            fi
        else
            log_error "Backup corrupto: $BACKUP_FILE"
            exit 1
        fi
    else
        log_error "Archivo de backup no encontrado: $BACKUP_FILE"
        exit 1
    fi
}

# Función principal
main() {
    log_info "=== KUBESPRAY CLUSTER BACKUP ==="
    log_info "Tipo de backup: $BACKUP_TYPE"
    
    check_prerequisites
    
    case $BACKUP_TYPE in
        "full")
            backup_etcd
            backup_resources
            backup_configuration
            ;;
        "etcd")
            backup_etcd
            ;;
        "resources")
            backup_resources
            backup_configuration
            ;;
        *)
            log_error "Tipo de backup no válido: $BACKUP_TYPE"
            show_help
            exit 1
            ;;
    esac
    
    # Comprimir y validar
    BACKUP_FILE=$(compress_backup)
    validate_backup "$BACKUP_FILE"
    
    # Limpiar backups antiguos
    cleanup_old_backups
    
    log_success "Backup completado exitosamente!"
    log_info "Archivo de backup: $BACKUP_FILE"
}

# Verificar argumentos
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    show_help
    exit 0
fi

# Ejecutar función principal
main "$@"
