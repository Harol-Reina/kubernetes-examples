#!/bin/bash

# Script de instalación de Local Path Provisioner para Bare Metal
# Configura almacenamiento local persistente dinámico

set -e

echo "🗄️  Instalando Local Path Provisioner para Bare Metal..."

# Verificar que kubectl está disponible
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

# Opción de instalación
echo ""
echo "Selecciona método de instalación:"
echo "1) Instalación oficial desde GitHub (recomendado)"
echo "2) Usar configuración local incluida"
read -p "Opción (1-2): " option

case $option in
    1)
        echo "📦 Instalando desde repositorio oficial..."
        kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml
        ;;
    2)
        echo "📦 Instalando desde configuración local..."
        kubectl apply -f local-path-provisioner.yaml
        kubectl apply -f storageclass-local.yaml
        ;;
    *)
        echo "❌ Opción inválida"
        exit 1
        ;;
esac

echo ""
echo "⏳ Esperando que el provisioner esté listo..."
kubectl wait --for=condition=ready pod -l app=local-path-provisioner -n local-path-storage --timeout=120s

echo ""
echo "🔧 Configurando StorageClass por defecto..."
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo ""
echo "✅ Local Path Provisioner instalado exitosamente!"
echo ""
echo "📋 Verificación:"
echo "   Pods: kubectl get pods -n local-path-storage"
echo "   StorageClasses: kubectl get storageclass"
echo ""
echo "🧪 Test rápido:"
echo "   kubectl apply -f test-pvc.yaml"
echo "   kubectl apply -f test-pod-with-storage.yaml"
echo ""
echo "🔗 Acceso al test:"
echo "   http://NODE_IP:30080"
echo ""
echo "📁 Directorio de almacenamiento en nodos:"
echo "   /opt/local-path-provisioner/"
echo ""
echo "💡 StorageClasses disponibles:"
echo "   - local-path (default): Eliminación automática"
echo "   - local-path-retain: Retiene datos al eliminar PVC"
echo "   - local-path-database: Para bases de datos"

# Mostrar configuración actual
echo ""
echo "📊 Estado actual:"
kubectl get storageclass
kubectl get pods -n local-path-storage
