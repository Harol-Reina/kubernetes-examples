#!/bin/bash

# Script de CI/CD para Minikube
# Este script automatiza el proceso de construcción, pruebas y despliegue

set -e  # Salir si cualquier comando falla

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de utilidad
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

# Variables de configuración
APP_NAME="mi-app"
BUILD_NUMBER=${BUILD_NUMBER:-$(date +%Y%m%d-%H%M%S)}
GIT_COMMIT=${GIT_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")}
GIT_BRANCH=${GIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")}
BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DOCKER_REGISTRY=${DOCKER_REGISTRY:-""}
NAMESPACE=${NAMESPACE:-"default"}

# Configuración por entorno
if [ "$GIT_BRANCH" = "main" ]; then
    ENVIRONMENT="production"
    REPLICAS=3
    SERVICE_TYPE="LoadBalancer"
elif [ "$GIT_BRANCH" = "develop" ]; then
    ENVIRONMENT="staging"
    REPLICAS=2
    SERVICE_TYPE="NodePort"
else
    ENVIRONMENT="test"
    REPLICAS=1
    SERVICE_TYPE="ClusterIP"
fi

IMAGE_TAG="${APP_NAME}:${BUILD_NUMBER}"
if [ -n "$DOCKER_REGISTRY" ]; then
    IMAGE_TAG="${DOCKER_REGISTRY}/${IMAGE_TAG}"
fi

# Función principal
main() {
    log_info "🚀 Iniciando pipeline CI/CD..."
    log_info "📋 Configuración:"
    log_info "   - App: $APP_NAME"
    log_info "   - Build: $BUILD_NUMBER"
    log_info "   - Commit: $GIT_COMMIT"
    log_info "   - Branch: $GIT_BRANCH"
    log_info "   - Environment: $ENVIRONMENT"
    log_info "   - Image: $IMAGE_TAG"
    
    # Verificar prerrequisitos
    check_prerequisites
    
    # Configurar entorno Docker para Minikube
    setup_docker_env
    
    # Construir imagen
    build_image
    
    # Ejecutar tests unitarios
    run_unit_tests
    
    # Desplegar a entorno de testing
    deploy_to_test
    
    # Ejecutar tests de integración
    run_integration_tests
    
    # Si es rama main, desplegar a producción
    if [ "$GIT_BRANCH" = "main" ]; then
        deploy_to_production
    fi
    
    # Cleanup
    cleanup
    
    log_success "✅ Pipeline completado exitosamente!"
}

# Verificar que las herramientas necesarias estén disponibles
check_prerequisites() {
    log_info "🔍 Verificando prerrequisitos..."
    
    local missing_tools=()
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v minikube &> /dev/null; then
        missing_tools+=("minikube")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Herramientas faltantes: ${missing_tools[*]}"
        exit 1
    fi
    
    # Verificar que Minikube esté corriendo
    if ! minikube status &> /dev/null; then
        log_error "Minikube no está corriendo. Ejecuta: minikube start"
        exit 1
    fi
    
    log_success "Prerrequisitos verificados"
}

# Configurar entorno Docker para Minikube
setup_docker_env() {
    log_info "🐳 Configurando entorno Docker..."
    eval $(minikube docker-env)
    log_success "Entorno Docker configurado"
}

# Construir imagen Docker
build_image() {
    log_info "🏗️  Construyendo imagen Docker..."
    
    # Crear Dockerfile si no existe
    if [ ! -f "Dockerfile" ]; then
        create_sample_dockerfile
    fi
    
    docker build \
        --build-arg BUILD_NUMBER="$BUILD_NUMBER" \
        --build-arg GIT_COMMIT="$GIT_COMMIT" \
        --build-arg BUILD_DATE="$BUILD_DATE" \
        -t "$IMAGE_TAG" \
        .
    
    # También tagear como latest para el entorno
    docker tag "$IMAGE_TAG" "${APP_NAME}:${ENVIRONMENT}"
    docker tag "$IMAGE_TAG" "${APP_NAME}:latest"
    
    log_success "Imagen construida: $IMAGE_TAG"
}

# Crear Dockerfile de ejemplo si no existe
create_sample_dockerfile() {
    log_warning "Dockerfile no encontrado, creando uno de ejemplo..."
    
    cat > Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copiar package.json
COPY package*.json ./

# Instalar dependencias
RUN npm ci --only=production

# Copiar código fuente
COPY . .

# Crear usuario no-root
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeuser -u 1001

# Cambiar a usuario no-root
USER nodeuser

# Exponer puerto
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Comando por defecto
CMD ["npm", "start"]
EOF
    
    log_info "Dockerfile de ejemplo creado"
}

# Ejecutar tests unitarios
run_unit_tests() {
    log_info "🧪 Ejecutando tests unitarios..."
    
    # Ejecutar tests dentro del contenedor
    docker run --rm "$IMAGE_TAG" npm test || {
        log_error "Tests unitarios fallaron"
        exit 1
    }
    
    log_success "Tests unitarios pasaron"
}

# Desplegar a entorno de testing
deploy_to_test() {
    log_info "🚀 Desplegando a entorno de testing..."
    
    # Generar manifiestos con variables de entorno
    export ENVIRONMENT="test"
    export BUILD_NUMBER
    export GIT_COMMIT
    export BUILD_DATE
    export REPLICAS=1
    export SERVICE_TYPE="ClusterIP"
    
    envsubst < kubernetes-config/deployment-template.yaml | kubectl apply -f -
    
    # Esperar a que esté listo
    kubectl wait --for=condition=ready pod -l app=$APP_NAME,environment=test --timeout=300s
    
    log_success "Aplicación desplegada en testing"
}

# Ejecutar tests de integración
run_integration_tests() {
    log_info "🔍 Ejecutando tests de integración..."
    
    # Aplicar Job de tests de integración
    kubectl apply -f kubernetes-config/test-deployment.yaml
    
    # Esperar a que el job complete
    kubectl wait --for=condition=complete job/integration-tests --timeout=300s || {
        log_error "Tests de integración fallaron"
        kubectl logs job/integration-tests
        exit 1
    }
    
    log_success "Tests de integración pasaron"
}

# Desplegar a producción
deploy_to_production() {
    log_info "🎯 Desplegando a producción..."
    
    # Confirmar despliegue a producción
    if [ "$SKIP_CONFIRMATION" != "true" ]; then
        read -p "¿Confirmas el despliegue a producción? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warning "Despliegue a producción cancelado"
            return 0
        fi
    fi
    
    # Actualizar imagen en producción
    kubectl set image deployment/mi-app-prod app="$IMAGE_TAG"
    
    # Esperar rollout
    kubectl rollout status deployment/mi-app-prod --timeout=600s
    
    # Verificar que la aplicación esté respondiendo
    sleep 30  # Dar tiempo para que se estabilice
    
    # Si hay un servicio LoadBalancer, probar conectividad
    SERVICE_IP=$(kubectl get service mi-app-prod-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$SERVICE_IP" ]; then
        if curl -f "http://$SERVICE_IP/health" &>/dev/null; then
            log_success "Aplicación en producción responde correctamente"
        else
            log_warning "Aplicación desplegada pero no responde en LoadBalancer"
        fi
    fi
    
    log_success "Despliegue a producción completado"
}

# Limpiar recursos temporales
cleanup() {
    log_info "🧹 Limpiando recursos temporales..."
    
    # Eliminar Job de tests de integración
    kubectl delete job integration-tests --ignore-not-found=true
    
    # Eliminar deployment de test si no es la rama de testing
    if [ "$ENVIRONMENT" != "test" ]; then
        kubectl delete deployment mi-app-test --ignore-not-found=true
        kubectl delete service mi-app-test-service --ignore-not-found=true
    fi
    
    # Limpiar imágenes Docker antiguas (mantener las últimas 3)
    docker images "${APP_NAME}" --format "table {{.Repository}}:{{.Tag}}\t{{.CreatedAt}}" | \
        tail -n +4 | \
        awk '{print $1}' | \
        xargs -r docker rmi || true
    
    log_success "Limpieza completada"
}

# Función para rollback
rollback() {
    local deployment=${1:-"mi-app-prod"}
    log_warning "🔄 Ejecutando rollback de $deployment..."
    
    kubectl rollout undo deployment/$deployment
    kubectl rollout status deployment/$deployment --timeout=300s
    
    log_success "Rollback completado"
}

# Función para mostrar ayuda
show_help() {
    echo "Pipeline CI/CD para Kubernetes"
    echo ""
    echo "Uso: $0 [COMMAND]"
    echo ""
    echo "Comandos:"
    echo "  main          - Ejecutar pipeline completo (por defecto)"
    echo "  build         - Solo construir imagen"
    echo "  test          - Solo ejecutar tests"
    echo "  deploy        - Solo desplegar"
    echo "  rollback      - Hacer rollback del último despliegue"
    echo "  cleanup       - Limpiar recursos"
    echo "  help          - Mostrar esta ayuda"
    echo ""
    echo "Variables de entorno:"
    echo "  BUILD_NUMBER       - Número de build (default: timestamp)"
    echo "  GIT_COMMIT         - Hash del commit (default: auto-detect)"
    echo "  GIT_BRANCH         - Rama de git (default: auto-detect)"
    echo "  DOCKER_REGISTRY    - Registry de Docker (default: none)"
    echo "  NAMESPACE          - Namespace de Kubernetes (default: default)"
    echo "  SKIP_CONFIRMATION  - Saltar confirmación de producción (default: false)"
    echo ""
    echo "Ejemplos:"
    echo "  $0                          # Pipeline completo"
    echo "  BUILD_NUMBER=123 $0        # Con número de build específico"
    echo "  SKIP_CONFIRMATION=true $0  # Sin confirmación para producción"
}

# Ejecutar comando basado en argumentos
case "${1:-main}" in
    main)
        main
        ;;
    build)
        check_prerequisites
        setup_docker_env
        build_image
        ;;
    test)
        check_prerequisites
        run_unit_tests
        ;;
    deploy)
        check_prerequisites
        deploy_to_test
        ;;
    rollback)
        rollback "${2:-mi-app-prod}"
        ;;
    cleanup)
        cleanup
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Comando desconocido: $1"
        show_help
        exit 1
        ;;
esac
