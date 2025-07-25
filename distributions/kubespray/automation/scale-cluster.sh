#!/bin/bash
# Scale Kubernetes Cluster with Kubespray
# Uso: ./scale-cluster.sh [add-workers|remove-workers|add-masters] [COUNT]

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
OPERATION="${1:-}"
COUNT="${2:-1}"
KUBESPRAY_DIR="${KUBESPRAY_DIR:-./kubespray}"
INVENTORY_DIR="${KUBESPRAY_DIR}/inventory/mycluster"

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [OPERACIÓN] [CANTIDAD]"
    echo ""
    echo "OPERACIONES:"
    echo "  add-workers     - Añadir nodos worker al cluster"
    echo "  remove-workers  - Remover nodos worker del cluster"
    echo "  add-masters     - Añadir nodos master al cluster (HA)"
    echo ""
    echo "CANTIDAD: Número de nodos a añadir/remover (por defecto: 1)"
    echo ""
    echo "Ejemplos:"
    echo "  $0 add-workers 3        # Añadir 3 workers"
    echo "  $0 remove-workers 1     # Remover 1 worker"
    echo "  $0 add-masters 2        # Añadir 2 masters"
    echo ""
    echo "Variables de entorno:"
    echo "  KUBESPRAY_DIR - Directorio de Kubespray (por defecto: ./kubespray)"
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

# Función para validar operación
validate_operation() {
    case $OPERATION in
        "add-workers"|"remove-workers"|"add-masters")
            log_info "Operación: $OPERATION"
            log_info "Cantidad: $COUNT"
            ;;
        *)
            log_error "Operación no válida: $OPERATION"
            show_help
            exit 1
            ;;
    esac
    
    # Validar que COUNT es un número
    if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
        log_error "La cantidad debe ser un número: $COUNT"
        exit 1
    fi
    
    if [ "$COUNT" -eq 0 ]; then
        log_error "La cantidad debe ser mayor que 0"
        exit 1
    fi
}

# Función para mostrar estado actual del cluster
show_current_state() {
    log_info "Estado actual del cluster:"
    kubectl get nodes -o wide
    
    # Contar nodos por tipo
    MASTER_COUNT=$(kubectl get nodes --no-headers -l node-role.kubernetes.io/control-plane | wc -l)
    WORKER_COUNT=$(kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' | wc -l)
    
    log_info "Masters: $MASTER_COUNT"
    log_info "Workers: $WORKER_COUNT"
    log_info "Total: $((MASTER_COUNT + WORKER_COUNT))"
}

# Función para añadir workers
add_workers() {
    log_info "Añadiendo $COUNT nodos worker..."
    
    log_warning "IMPORTANTE: Debes tener los nuevos nodos ya aprovisionados y configurados"
    log_info "Instrucciones:"
    echo "1. Aprovisiona $COUNT nuevos nodos"
    echo "2. Configura SSH key-based authentication"
    echo "3. Asegúrate de que tienen privilegios sudo"
    echo "4. Añádelos al archivo $INVENTORY_DIR/hosts.yaml"
    echo ""
    
    read -p "¿Has completado estos pasos? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operación cancelada. Completa los pasos y vuelve a ejecutar."
        exit 0
    fi
    
    # Verificar conectividad a nuevos nodos
    log_info "Verificando conectividad a todos los nodos..."
    if ! ansible all -i "$INVENTORY_DIR/hosts.yaml" -m ping; then
        log_error "Error de conectividad. Verifica la configuración de los nuevos nodos."
        exit 1
    fi
    
    # Ejecutar playbook para añadir nodos
    cd "$KUBESPRAY_DIR"
    
    log_info "Ejecutando playbook scale.yml..."
    if ansible-playbook -i "$INVENTORY_DIR/hosts.yaml" \
        --become --become-user=root \
        scale.yml; then
        log_success "Nodos worker añadidos exitosamente!"
    else
        log_error "Error al añadir nodos worker"
        exit 1
    fi
    
    cd - > /dev/null
}

# Función para remover workers
remove_workers() {
    log_info "Removiendo $COUNT nodos worker..."
    
    # Mostrar workers disponibles para remover
    log_info "Workers disponibles para remover:"
    kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' | nl -v0
    
    echo ""
    log_warning "Especifica los nodos a remover separados por coma:"
    read -p "Nodos a remover (ej: worker3,worker4): " NODES_TO_REMOVE
    
    if [ -z "$NODES_TO_REMOVE" ]; then
        log_error "No se especificaron nodos para remover"
        exit 1
    fi
    
    # Confirmar remoción
    echo ""
    log_warning "¿Estás seguro de que quieres remover estos nodos?"
    log_info "Nodos: $NODES_TO_REMOVE"
    echo ""
    read -p "Continuar? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operación cancelada"
        exit 0
    fi
    
    # Drenar nodos antes de remover
    log_info "Drenando nodos..."
    IFS=',' read -ra NODES <<< "$NODES_TO_REMOVE"
    for node in "${NODES[@]}"; do
        log_info "Drenando nodo: $node"
        kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --force || true
    done
    
    # Ejecutar playbook para remover nodos
    cd "$KUBESPRAY_DIR"
    
    log_info "Ejecutando playbook remove-node.yml..."
    if ansible-playbook -i "$INVENTORY_DIR/hosts.yaml" \
        --become --become-user=root \
        remove-node.yml \
        --extra-vars "node=$NODES_TO_REMOVE"; then
        log_success "Nodos worker removidos exitosamente!"
    else
        log_error "Error al remover nodos worker"
        exit 1
    fi
    
    cd - > /dev/null
    
    # Limpiar nodos del inventario
    log_info "Recuerda actualizar el archivo de inventario para remover los nodos:"
    log_info "$INVENTORY_DIR/hosts.yaml"
}

# Función para añadir masters
add_masters() {
    log_info "Añadiendo $COUNT nodos master..."
    
    # Verificar que no se añadan demasiados masters
    CURRENT_MASTERS=$(kubectl get nodes --no-headers -l node-role.kubernetes.io/control-plane | wc -l)
    TOTAL_MASTERS=$((CURRENT_MASTERS + COUNT))
    
    if [ $((TOTAL_MASTERS % 2)) -eq 0 ]; then
        log_warning "Tendrás $TOTAL_MASTERS masters (número par)"
        log_warning "Para alta disponibilidad se recomienda un número impar de masters"
        read -p "¿Continuar? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Operación cancelada"
            exit 0
        fi
    fi
    
    log_warning "IMPORTANTE: Debes tener los nuevos nodos master ya aprovisionados"
    log_info "Instrucciones:"
    echo "1. Aprovisiona $COUNT nuevos nodos para masters"
    echo "2. Configura SSH key-based authentication"
    echo "3. Asegúrate de que tienen privilegios sudo"
    echo "4. Añádelos al archivo $INVENTORY_DIR/hosts.yaml en los grupos:"
    echo "   - kube_control_plane"
    echo "   - etcd"
    echo ""
    
    read -p "¿Has completado estos pasos? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operación cancelada. Completa los pasos y vuelve a ejecutar."
        exit 0
    fi
    
    # Verificar conectividad
    log_info "Verificando conectividad a todos los nodos..."
    if ! ansible all -i "$INVENTORY_DIR/hosts.yaml" -m ping; then
        log_error "Error de conectividad. Verifica la configuración de los nuevos nodos."
        exit 1
    fi
    
    # Ejecutar playbook para añadir masters
    cd "$KUBESPRAY_DIR"
    
    log_info "Ejecutando playbook cluster.yml para añadir masters..."
    if ansible-playbook -i "$INVENTORY_DIR/hosts.yaml" \
        --become --become-user=root \
        cluster.yml \
        --limit=kube_control_plane; then
        log_success "Nodos master añadidos exitosamente!"
    else
        log_error "Error al añadir nodos master"
        exit 1
    fi
    
    cd - > /dev/null
}

# Función para verificar escalado
verify_scaling() {
    log_info "Verificando escalado del cluster..."
    
    # Esperar a que el cluster se estabilice
    sleep 30
    
    # Mostrar nuevo estado
    log_info "Nuevo estado del cluster:"
    kubectl get nodes -o wide
    
    # Verificar que todos los nodos están listos
    NOT_READY_NODES=$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l)
    if [ "$NOT_READY_NODES" -gt 0 ]; then
        log_warning "Hay $NOT_READY_NODES nodos no listos"
        kubectl get nodes --no-headers | grep -v " Ready "
    else
        log_success "Todos los nodos están listos"
    fi
    
    # Verificar pods del sistema
    log_info "Verificando pods del sistema..."
    kubectl get pods --all-namespaces | grep -E "(kube-system|kube-public)"
    
    log_success "Verificación del escalado completada"
}

# Función principal
main() {
    log_info "=== KUBESPRAY CLUSTER SCALING ==="
    
    check_prerequisites
    validate_operation
    show_current_state
    
    case $OPERATION in
        "add-workers")
            add_workers
            ;;
        "remove-workers")
            remove_workers
            ;;
        "add-masters")
            add_masters
            ;;
    esac
    
    verify_scaling
    
    log_success "Operación de escalado completada!"
}

# Verificar argumentos
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ -z "$OPERATION" ]; then
    show_help
    exit 0
fi

# Ejecutar función principal
main "$@"
