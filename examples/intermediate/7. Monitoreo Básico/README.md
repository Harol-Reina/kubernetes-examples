# 7. Monitoreo Básico - Stack Ligero Prometheus + Grafana

Stack de observabilidad optimizado para clusters bare metal con recursos limitados, diseñado para funcionar con configuraciones mínimas pero manteniendo funcionalidad completa de monitoreo.

## 🎯 Optimizaciones para Bare Metal

### 💾 Recursos Limitados
- **Prometheus**: 5GB de almacenamiento, 7 días de retención
- **Grafana**: 2GB de almacenamiento para dashboards
- **Memoria**: Configuraciones optimizadas para clusters pequeños
- **CPU**: Requests mínimos para nodos con pocos recursos

### 🔒 Sin Certificados Firmados
- **HTTP únicamente**: No requiere TLS/SSL
- **Comunicación interna**: Todo por ClusterIP
- **Acceso**: Via port-forward o NodePort
- **Simplicidad**: Sin complejidad de certificados

### ⚡ Funcionalidad Completa
- **Métricas de cluster**: Kubernetes API, kubelet, pods
- **Métricas de nodos**: CPU, memoria, disco, red
- **Alertas básicas**: NodeDown, HighCPU, HighMemory
- **Dashboards esenciales**: Cluster overview, node metrics

## 📊 Componentes del Stack Ligero

### 🔍 Prometheus (Configuración Mínima)
- **Scraping optimizado**: Solo métricas esenciales
- **Retención reducida**: 7 días vs 30 días en producción
- **Almacenamiento**: 5GB con limpieza automática
- **Alertas básicas**: Solo las críticas para bare metal

### 📈 Grafana (Esencial)
- **Dashboards mínimos**: Solo los más importantes
- **Sin plugins**: Configuración básica sin extensiones
- **Almacenamiento mínimo**: 2GB para configuraciones
- **Acceso HTTP**: Sin HTTPS para simplicidad

### 📊 Node Exporter (Optimizado)
- **Métricas selectivas**: Solo las más importantes
- **Memoria mínima**: 32Mi request, 64Mi limit
- **CPU reducida**: 25m request, 50m limit

## 🚀 Instalación Rápida

### Prerrequisitos para Bare Metal

#### 1. Recursos Mínimos
```bash
# Verificar que el cluster tiene suficientes recursos
kubectl top nodes
kubectl describe nodes

# Verificar espacio disponible (necesario: ~8GB total)
kubectl get nodes -o wide
```

#### 2. StorageClass (Requerido)
```bash
# Verificar StorageClass disponible
kubectl get storageclass

# Si no tienes local-path, instalar Local Path Provisioner:
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Configurar como default
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

#### 3. Directorio en Nodos
```bash
# En cada nodo, crear directorio para storage
sudo mkdir -p /opt/local-path-provisioner
sudo chmod 755 /opt/local-path-provisioner
```

## 🚀 Instalación

### Opción 1: All-in-One (Recomendado)
```bash
# Deployment completo en un solo comando
kubectl apply -f monitoring-stack.yaml
```

### Opción 2: Script Automatizado
```bash
# Ejecutar script de deployment
./deploy.sh
```

### Opción 3: Deployment Individual
```bash
# Crear namespace
kubectl create namespace monitoring

# Desplegar componentes por separado
kubectl apply -f prometheus/
kubectl apply -f grafana/
kubectl apply -f node-exporter/
kubectl apply -f kube-state-metrics/
```

### Opción 1: Stack Completo (Recomendado)
```bash
# Crear namespace de monitoreo
kubectl create namespace monitoring

# Desplegar stack ligero
kubectl apply -f examples/intermediate/"7. Monitoreo Básico/"
```

### Opción 2: Por Componentes
```bash
# 1. RBAC y Prometheus
kubectl apply -f examples/intermediate/"7. Monitoreo Básico/prometheus/"

# 2. Node Exporter optimizado
kubectl apply -f examples/intermediate/"7. Monitoreo Básico/node-exporter/"

# 3. Grafana básico
kubectl apply -f examples/intermediate/"7. Monitoreo Básico/grafana/"
```

## 🔧 Acceso a los Servicios

### Para Clusters Bare Metal

#### Opción 1: Port Forward (Desarrollo/Testing)
```bash
# Prometheus
kubectl port-forward -n monitoring service/prometheus 9090:9090

# Grafana
kubectl port-forward -n monitoring service/grafana 3000:3000

# Acceder desde el navegador:
# Prometheus: http://localhost:9090
# Grafana: http://localhost:3000 (admin/admin)
```

#### Opción 2: NodePort (Acceso desde red local)
```bash
# Verificar NodePorts asignados
kubectl get services -n monitoring

# Acceder usando IP del nodo + puerto
# Ejemplo: http://192.168.1.100:30090 (Prometheus)
# Ejemplo: http://192.168.1.100:30030 (Grafana)
```

#### Opción 3: Ingress (Si tienes controlador)
```bash
# Aplicar configuración de Ingress
kubectl apply -f ingress-monitoring.yaml

# Acceder via hostname configurado
# http://monitoring.local/prometheus
# http://monitoring.local/grafana
```

## 📋 Métricas Monitoreadas

### Cluster Level (Mínimas pero Completas)
```bash
# Estado de nodos
kube_node_status_ready

# Estado de pods críticos
kube_pod_status_phase{namespace="kube-system"}

# Recursos del cluster
cluster_quantile:apiserver_request_duration_seconds:histogram_quantile
```

### Node Level (Optimizadas)
```bash
# Uso de memoria
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes

# Uso de CPU
rate(node_cpu_seconds_total{mode!="idle"}[5m])

# Espacio en disco
node_filesystem_avail_bytes{fstype!="tmpfs"}
```

### Pod Level (Esenciales)
```bash
# Memoria por contenedor
container_memory_working_set_bytes{container!="POD"}

# CPU por contenedor
rate(container_cpu_usage_seconds_total{container!="POD"}[5m])

# Restarts de pods
kube_pod_container_status_restarts_total
```

## 🚨 Alertas para Bare Metal

### Critical (Solo las Esenciales)
```yaml
# Nodo down - crítico en bare metal
- alert: NodeDown
  expr: up{job="kubernetes-nodes"} == 0
  for: 3m

# Memoria alta - crítico con pocos recursos
- alert: HighMemoryUsage
  expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.85
  for: 5m

# Disco lleno - crítico en sistemas pequeños
- alert: DiskSpaceLow
  expr: node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"} < 0.1
  for: 5m
```

### Warning (Preventivas)
```yaml
# Pod crash looping
- alert: PodCrashLooping
  expr: rate(kube_pod_container_status_restarts_total[10m]) > 0
  for: 5m

# CPU alto sostenido
- alert: HighCPUUsage
  expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
  for: 10m
```

## 🛠️ Comandos Útiles para Bare Metal

### Verificación del Stack
```bash
# Ver recursos consumidos
kubectl top pods -n monitoring
kubectl describe pods -n monitoring

# Ver almacenamiento usado
kubectl get pvc -n monitoring
kubectl describe pvc -n monitoring

# Verificar configuración de Prometheus
kubectl logs -n monitoring deployment/prometheus | grep -i error
```

### Optimización de Recursos
```bash
# Verificar límites de memoria
kubectl describe deployment prometheus -n monitoring

# Monitorear uso real
kubectl top pods -n monitoring --containers

# Ajustar si es necesario
kubectl edit deployment prometheus -n monitoring
```

### Troubleshooting Específico
```bash
# Verificar targets de Prometheus
# Acceder a http://localhost:9090/targets

# Ver métricas disponibles
curl http://localhost:9090/api/v1/label/__name__/values

# Verificar conectividad entre componentes
kubectl exec -n monitoring deployment/prometheus -- nslookup grafana
kubectl exec -n monitoring deployment/grafana -- nslookup prometheus
```

## 📊 Dashboards Incluidos (Optimizados)

### 1. Cluster Overview (Simplificado)
- **Nodos activos**: Estado de nodos del cluster
- **Pods por namespace**: Distribución de cargas
- **Recursos críticos**: CPU/Memoria del cluster
- **Alertas activas**: Solo las más importantes

### 2. Node Metrics (Bare Metal Focus)
- **Recursos por nodo**: CPU, RAM, disco de cada nodo
- **Red por interfaz**: Tráfico de red simplificado
- **Load average**: Carga del sistema
- **Filesystem usage**: Uso de disco por punto de montaje

### 3. Troubleshooting Dashboard
- **Pod restarts**: Historial de restarts reciente
- **Failed pods**: Pods en estado fallido
- **Resource usage**: Top consumers de CPU/memoria
- **Network errors**: Errores de red básicos

## 🔧 Configuraciones Específicas para Bare Metal

### Retención de Datos Optimizada
```yaml
# Prometheus configuration
retention.time: "7d"     # Solo 7 días vs 30 días
retention.size: "4GB"    # Máximo 4GB de 5GB disponibles
scrape_interval: "30s"   # Menos frecuente para ahorrar recursos
```

### Recursos Ajustados
```yaml
# Requests mínimos para nodos pequeños
resources:
  requests:
    memory: "256Mi"  # vs 512Mi en producción
    cpu: "100m"      # vs 250m en producción
  limits:
    memory: "512Mi"  # vs 2Gi en producción
    cpu: "500m"      # vs 1000m en producción
```

### Selectores de Métricas
```yaml
# Solo métricas esenciales para ahorrar recursos
metric_relabel_configs:
- source_labels: [__name__]
  regex: 'node_(cpu|memory|filesystem|network).*'
  action: keep
```

## 🚀 Escalabilidad en Bare Metal

### Escalado Vertical (Más recursos al mismo pod)
```bash
# Aumentar recursos si el nodo lo permite
kubectl patch deployment prometheus -n monitoring -p '{"spec":{"template":{"spec":{"containers":[{"name":"prometheus","resources":{"requests":{"memory":"512Mi"}}}]}}}}'
```

### Optimización de Almacenamiento
```bash
# Usar almacenamiento local para mejor performance
# Configurar hostPath o local PVs
# Evitar network storage si es posible
```

### Federación Ligera (Para múltiples clusters pequeños)
```yaml
# Configurar un Prometheus central que recoja métricas de otros
- job_name: 'federate'
  scrape_interval: 15s
  honor_labels: true
  metrics_path: '/federate'
  params:
    'match[]':
      - '{job=~"kubernetes.*"}'
  static_configs:
    - targets:
      - 'cluster1-prometheus:9090'
      - 'cluster2-prometheus:9090'
```

## 📚 Referencias para Bare Metal

- [Prometheus Configuration for Small Clusters](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- [Grafana Lightweight Setup](https://grafana.com/docs/grafana/latest/installation/)
- [Kubernetes Monitoring on Bare Metal](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-usage-monitoring/)
- [Node Exporter Best Practices](https://github.com/prometheus/node_exporter)

## 🎯 Próximos Pasos

1. **Monitorear el rendimiento** del stack después del despliegue
2. **Ajustar recursos** según el uso real observado
3. **Añadir métricas custom** de aplicaciones específicas
4. **Configurar backups** de configuraciones de Grafana
5. **Implementar alertas** via webhook o email si es necesario

## ⚠️ Consideraciones Importantes

### Limitaciones del Setup Ligero
- **Retención corta**: Solo 7 días de métricas históricas
- **Sin HA**: Un solo pod de Prometheus/Grafana
- **Sin TLS**: Comunicación HTTP únicamente
- **Métricas limitadas**: Solo las más esenciales

### Recomendaciones para Producción
- **Backup regular**: De configuraciones y dashboards
- **Monitoreo del monitor**: Alertas sobre el propio stack
- **Documentación**: De configuraciones específicas del entorno
- **Testing de recovery**: Procedimientos de recuperación

---

**💡 Tip para Bare Metal**: Este stack está optimizado para recursos limitados pero mantiene funcionalidad completa. Ajusta los recursos según tu hardware específico.

**🔧 Optimización**: Monitorea el uso real de recursos después del despliegue y ajusta los límites según sea necesario para tu entorno específico.
