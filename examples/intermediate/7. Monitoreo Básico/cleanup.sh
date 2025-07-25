#!/bin/bash

# Monitoreo Básico para Bare Metal - Cleanup Script
# Este script elimina completamente la solución de monitoreo

set -e

echo "🗑️  Eliminando Monitoreo Básico..."

# Eliminar en orden inverso para evitar dependencias
echo "🎨 Eliminando Grafana..."
kubectl delete -f grafana/grafana-service.yaml --ignore-not-found=true
kubectl delete -f grafana/grafana-deployment.yaml --ignore-not-found=true
kubectl delete -f grafana/grafana-configmap.yaml --ignore-not-found=true

echo "📈 Eliminando Kube State Metrics..."
kubectl delete -f kube-state-metrics/kube-state-metrics-service.yaml --ignore-not-found=true
kubectl delete -f kube-state-metrics/kube-state-metrics-deployment.yaml --ignore-not-found=true
kubectl delete -f kube-state-metrics/kube-state-metrics-rbac.yaml --ignore-not-found=true
kubectl delete -f kube-state-metrics/kube-state-metrics-serviceaccount.yaml --ignore-not-found=true

echo "📊 Eliminando Node Exporter..."
kubectl delete -f node-exporter/node-exporter-service.yaml --ignore-not-found=true
kubectl delete -f node-exporter/node-exporter-daemonset.yaml --ignore-not-found=true
kubectl delete -f node-exporter/node-exporter-serviceaccount.yaml --ignore-not-found=true

echo "🔧 Eliminando Prometheus..."
kubectl delete -f prometheus/prometheus-service.yaml --ignore-not-found=true
kubectl delete -f prometheus/prometheus-deployment.yaml --ignore-not-found=true
kubectl delete -f prometheus/prometheus-configmap.yaml --ignore-not-found=true
kubectl delete -f prometheus/prometheus-rbac.yaml --ignore-not-found=true
kubectl delete -f prometheus/prometheus-serviceaccount.yaml --ignore-not-found=true

echo "📦 Eliminando namespace monitoring (opcional)..."
read -p "¿Eliminar namespace monitoring? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete namespace monitoring --ignore-not-found=true
    echo "📦 Namespace monitoring eliminado"
else
    echo "📦 Namespace monitoring conservado"
fi

echo ""
echo "✅ Monitoreo Básico eliminado exitosamente!"
echo "🔍 Verificar eliminación:"
echo "   kubectl get pods -n monitoring"
