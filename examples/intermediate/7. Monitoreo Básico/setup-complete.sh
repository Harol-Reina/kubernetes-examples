#!/bin/bash

# Setup Completo: Storage Local + Monitoreo Básico para Bare Metal
# Este script configura todo lo necesario para monitoreo con almacenamiento persistente

set -e

echo "🚀 Setup Completo: Storage + Monitoreo para Bare Metal"
echo "=============================================="

# Verificar kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl no está instalado"
    exit 1
fi

# Verificar conexión al cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ No hay conexión al cluster Kubernetes"
    exit 1
fi

echo "✅ Cluster Kubernetes detectado"

# Paso 1: Instalar Local Path Provisioner si no existe
echo ""
echo "📝 Paso 1: Configurando Storage Local"
echo "------------------------------------"

if kubectl get storageclass local-path &>/dev/null; then
    echo "✅ StorageClass 'local-path' ya existe"
else
    echo "📦 Instalando Local Path Provisioner..."
    
    # Preguntar método de instalación
    echo "Selecciona método de instalación:"
    echo "1) Desde repositorio oficial (recomendado)"
    echo "2) Usar configuración local"
    read -p "Opción (1-2): " storage_option
    
    case $storage_option in
        1)
            kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
            ;;
        2)
            if [ -f "../8. Storage Local/local-path-provisioner.yaml" ]; then
                kubectl apply -f "../8. Storage Local/local-path-provisioner.yaml"
                kubectl apply -f "../8. Storage Local/storageclass-local.yaml"
            else
                echo "❌ Archivos de configuración local no encontrados"
                echo "Usando instalación oficial..."
                kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
            fi
            ;;
        *)
            echo "Usando instalación oficial por defecto..."
            kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
            ;;
    esac
    
    echo "⏳ Esperando que el provisioner esté listo..."
    kubectl wait --for=condition=ready pod -l app=local-path-provisioner -n local-path-storage --timeout=120s
    
    echo "🔧 Configurando como StorageClass por defecto..."
    kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
fi

# Paso 2: Crear directorios en nodos (informativo)
echo ""
echo "📝 Paso 2: Configuración de Nodos"
echo "---------------------------------"
echo "ℹ️  Asegúrate de que en cada nodo exista el directorio:"
echo "   sudo mkdir -p /opt/local-path-provisioner"
echo "   sudo chmod 755 /opt/local-path-provisioner"
echo ""
read -p "¿Has configurado los directorios en todos los nodos? (y/N): " nodes_ready

if [[ ! $nodes_ready =~ ^[Yy]$ ]]; then
    echo "⚠️  Configura los directorios en los nodos antes de continuar"
    echo "💡 Script para ejecutar en cada nodo:"
    echo "   sudo mkdir -p /opt/local-path-provisioner && sudo chmod 755 /opt/local-path-provisioner"
    exit 1
fi

# Paso 3: Desplegar Monitoreo
echo ""
echo "📝 Paso 3: Desplegando Stack de Monitoreo"
echo "-----------------------------------------"

echo "Selecciona método de deployment:"
echo "1) All-in-One (rápido)"
echo "2) Componentes individuales (detallado)"
read -p "Opción (1-2): " monitoring_option

case $monitoring_option in
    1)
        echo "📦 Desplegando con all-in-one..."
        kubectl apply -f monitoring-stack.yaml
        ;;
    2)
        echo "📦 Ejecutando script de deployment detallado..."
        ./deploy.sh
        ;;
    *)
        echo "Usando all-in-one por defecto..."
        kubectl apply -f monitoring-stack.yaml
        ;;
esac

# Verificación final
echo ""
echo "📝 Paso 4: Verificación Final"
echo "-----------------------------"

echo "⏳ Esperando que todos los pods estén listos..."
sleep 10

echo ""
echo "📊 Estado del Storage:"
kubectl get storageclass
kubectl get pvc -n monitoring

echo ""
echo "📊 Estado del Monitoreo:"
kubectl get pods -n monitoring

echo ""
echo "🎉 ¡Setup completado exitosamente!"
echo ""
echo "🔗 Acceso a los servicios:"
echo "   Prometheus: http://NODE_IP:30090"
echo "   Grafana: http://NODE_IP:30030 (admin/admin123)"
echo ""
echo "📊 Para obtener la IP de los nodos:"
echo "   kubectl get nodes -o wide"
echo ""
echo "💾 Ubicación del storage en nodos:"
echo "   /opt/local-path-provisioner/"
echo ""
echo "🔍 Comandos útiles:"
echo "   kubectl get pods -n monitoring"
echo "   kubectl get pvc -n monitoring"
echo "   kubectl logs -n monitoring deployment/prometheus"
echo "   kubectl logs -n monitoring deployment/grafana"
echo ""
echo "🧹 Para limpiar todo:"
echo "   ./cleanup.sh"
echo "   kubectl delete -f kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml"
