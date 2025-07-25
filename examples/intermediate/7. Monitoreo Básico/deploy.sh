#!/bin/bash

# Monitoreo Básico para Bare Metal - Deployment Script
# Este script despliega una solución de monitoreo optimizada para recursos limitados

set -e

echo "🚀 Desplegando Monitoreo Básico para Bare Metal..."
echo "Recursos optimizados: Prometheus 5GB, Grafana 2GB, sin TLS"

# Crear namespace
echo "📦 Creando namespace monitoring..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Desplegar Prometheus
echo "🔧 Desplegando Prometheus..."
kubectl apply -f prometheus/prometheus-serviceaccount.yaml
kubectl apply -f prometheus/prometheus-rbac.yaml
kubectl apply -f prometheus/prometheus-configmap.yaml
kubectl apply -f prometheus/prometheus-deployment.yaml
kubectl apply -f prometheus/prometheus-service.yaml

# Desplegar Node Exporter
echo "📊 Desplegando Node Exporter..."
kubectl apply -f node-exporter/node-exporter-serviceaccount.yaml
kubectl apply -f node-exporter/node-exporter-daemonset.yaml
kubectl apply -f node-exporter/node-exporter-service.yaml

# Desplegar Kube State Metrics
echo "📈 Desplegando Kube State Metrics..."
kubectl apply -f kube-state-metrics/kube-state-metrics-serviceaccount.yaml
kubectl apply -f kube-state-metrics/kube-state-metrics-rbac.yaml
kubectl apply -f kube-state-metrics/kube-state-metrics-deployment.yaml
kubectl apply -f kube-state-metrics/kube-state-metrics-service.yaml

# Desplegar Grafana
echo "🎨 Desplegando Grafana..."
kubectl apply -f grafana/grafana-configmap.yaml
kubectl apply -f grafana/grafana-deployment.yaml
kubectl apply -f grafana/grafana-service.yaml

echo ""
echo "✅ Monitoreo Básico desplegado exitosamente!"
echo ""
echo "🔗 Acceso a los servicios:"
echo "   Prometheus: http://NODE_IP:30090"
echo "   Grafana: http://NODE_IP:30030 (admin/admin123)"
echo ""
echo "📊 Para obtener la IP de los nodos:"
echo "   kubectl get nodes -o wide"
echo ""
echo "🔍 Verificar pods:"
echo "   kubectl get pods -n monitoring"
echo ""
echo "📋 Dashboard predeterminado: 'Bare Metal Cluster Overview'"
echo "💡 Login inicial en Grafana: admin/admin123 (cambiar password)"
echo ""
echo "⚙️  Configuración optimizada para bare metal:"
echo "   - Prometheus: 7 días retención, 4GB storage"
echo "   - Grafana: Sin TLS, acceso directo"
echo "   - Node Exporter: Collectors esenciales únicamente"
echo "   - Intervalos de scraping: 60s para reducir carga"
