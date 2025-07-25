# 5. Monitoreo - Stack Prometheus + Grafana

Stack completo de observabilidad para clusters de Kubernetes en producción, incluyendo métricas, visualización y alertas.

## 📊 Componentes del Stack

### 🔍 Prometheus
- **Scraping de métricas**: Recolección automática de métricas del cluster
- **Alertas**: Configuración de reglas de alerta
- **Persistencia**: Almacenamiento de métricas históricas
- **RBAC**: Permisos para acceder a métricas del cluster

### 📈 Grafana
- **Dashboards**: Visualización de métricas de Kubernetes
- **Datasources**: Conexión automática con Prometheus
- **Persistencia**: Almacenamiento de dashboards personalizados
- **Usuarios**: Configuración de acceso y roles

### 📊 Exporters y Métricas
- **Node Exporter**: Métricas de sistema de los nodos
- **Kube State Metrics**: Métricas del estado del cluster K8s
- **cAdvisor**: Métricas de contenedores (incluido en kubelet)

## 🚀 Instalación Rápida

### Opción 1: Stack Completo (Recomendado)
```bash
# Crear namespace de monitoreo
kubectl create namespace monitoring

# Desplegar todo el stack
kubectl apply -f examples/production/"5. Monitoreo/"
```

### Opción 2: Por Componentes
```bash
# 1. RBAC y configuración de Prometheus
kubectl apply -f examples/production/"5. Monitoreo/prometheus/"

# 2. Node Exporter para métricas de sistema
kubectl apply -f examples/production/"5. Monitoreo/node-exporter/"

# 3. Kube State Metrics para métricas de K8s
kubectl apply -f examples/production/"5. Monitoreo/kube-state-metrics/"

# 4. Grafana para visualización
kubectl apply -f examples/production/"5. Monitoreo/grafana/"
```

## 🔧 Configuración

### Acceso a los Servicios

#### Prometheus
```bash
# Port forward para acceso local
kubectl port-forward -n monitoring service/prometheus 9090:9090

# Acceder en: http://localhost:9090
```

#### Grafana
```bash
# Port forward para acceso local
kubectl port-forward -n monitoring service/grafana 3000:3000

# Acceder en: http://localhost:3000
# Usuario: admin
# Contraseña: admin (cambiar en primer acceso)
```

### Configuraciones Personalizadas

#### Prometheus Targets
Edita `prometheus/prometheus-config.yaml` para añadir nuevos targets:
```yaml
- job_name: 'custom-app'
  static_configs:
  - targets: ['custom-app:8080']
```

#### Dashboards de Grafana
Los dashboards están preconfigurados en `grafana/grafana-configmap.yaml`:
- **Kubernetes Cluster Overview**: Vista general del cluster
- **Node Metrics**: Métricas detalladas de nodos
- **Pod Metrics**: Métricas de pods y contenedores

## 📋 Métricas Importantes

### Cluster Level
- `kube_node_status_ready` - Estado de nodos
- `kube_pod_status_phase` - Estado de pods
- `kube_deployment_status_replicas` - Réplicas de deployments

### Node Level
- `node_memory_MemAvailable_bytes` - Memoria disponible
- `node_cpu_seconds_total` - Uso de CPU
- `node_filesystem_avail_bytes` - Espacio disponible en disco

### Pod Level
- `container_memory_usage_bytes` - Uso de memoria por contenedor
- `container_cpu_usage_seconds_total` - Uso de CPU por contenedor
- `container_fs_usage_bytes` - Uso de disco por contenedor

## 🚨 Alertas Preconfiguradas

### Critical Alerts
- **NodeDown**: Nodo no disponible
- **PodCrashLooping**: Pod en crash loop
- **HighMemoryUsage**: Uso alto de memoria (>90%)
- **HighCPUUsage**: Uso alto de CPU (>95%)

### Warning Alerts
- **PodNotReady**: Pod no está listo
- **LowDiskSpace**: Poco espacio en disco (<10%)
- **HighPodRestarts**: Muchos restarts de pods

## 🛠️ Comandos Útiles

### Verificación del Stack
```bash
# Ver todos los pods de monitoreo
kubectl get pods -n monitoring

# Ver servicios de monitoreo
kubectl get services -n monitoring

# Ver ConfigMaps
kubectl get configmaps -n monitoring

# Ver PersistentVolumes
kubectl get pv,pvc -n monitoring
```

### Troubleshooting
```bash
# Logs de Prometheus
kubectl logs -n monitoring deployment/prometheus

# Logs de Grafana
kubectl logs -n monitoring deployment/grafana

# Verificar configuración de Prometheus
kubectl describe configmap -n monitoring prometheus-config

# Verificar targets de Prometheus
# Acceder a http://localhost:9090/targets después del port-forward
```

### Scaling y Recursos
```bash
# Escalar Prometheus (si necesitas más recursos)
kubectl scale deployment prometheus -n monitoring --replicas=2

# Ver uso de recursos
kubectl top pods -n monitoring
kubectl top nodes
```

## 📊 Dashboards Incluidos

### 1. Kubernetes Cluster Overview
- **Nodes**: Estado y métricas de nodos
- **Pods**: Estado y distribución de pods
- **Resources**: Uso de CPU, memoria y disco del cluster

### 2. Node Metrics Dashboard
- **System Metrics**: CPU, memoria, disco por nodo
- **Network**: Tráfico de red por interfaz
- **Load**: Load average y procesos

### 3. Pod Metrics Dashboard
- **Container Metrics**: Uso de recursos por contenedor
- **Restart History**: Historial de restarts
- **Network**: Tráfico de red por pod

### 4. Application Metrics (Template)
- **Custom Metrics**: Plantilla para métricas de aplicación
- **Business Metrics**: KPIs y métricas de negocio
- **SLA/SLO**: Indicadores de nivel de servicio

## 🔐 Seguridad

### RBAC Configuration
El stack incluye configuración RBAC mínima necesaria:
- **ClusterRole**: Permisos de lectura para métricas
- **ServiceAccount**: Cuenta dedicada para Prometheus
- **RoleBinding**: Vinculación de permisos

### Network Policies
```yaml
# Ejemplo de política de red para el namespace monitoring
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: monitoring-network-policy
  namespace: monitoring
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090
    - protocol: TCP
      port: 3000
```

## 📈 Escalabilidad

### High Availability
Para configurar HA del stack de monitoreo:

```bash
# Prometheus HA (requiere configuración adicional)
kubectl scale deployment prometheus -n monitoring --replicas=2

# Grafana con múltiples réplicas
kubectl scale deployment grafana -n monitoring --replicas=2

# Usar LoadBalancer o Ingress para distribución
```

### Persistent Storage
Los PVCs están configurados para:
- **Prometheus**: 50Gi para retención de métricas
- **Grafana**: 10Gi para dashboards y configuración

### Retention Policies
Configuración de retención en Prometheus:
```yaml
retention.time: "30d"  # 30 días de retención
retention.size: "45GB" # Máximo 45GB de datos
```

## 🚀 Integración con Alertmanager

Para añadir Alertmanager al stack:

```bash
# Crear configuración de Alertmanager
kubectl apply -f alertmanager/

# Configurar webhook para Slack/Teams
# Editar alertmanager-config.yaml con tus webhooks
```

## 📚 Referencias y Recursos

- [Documentación de Prometheus](https://prometheus.io/docs/)
- [Documentación de Grafana](https://grafana.com/docs/)
- [Kubernetes Monitoring Guide](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-usage-monitoring/)
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
- [Grafana Dashboards para K8s](https://grafana.com/grafana/dashboards/?search=kubernetes)

## 🎯 Próximos Pasos

1. **Personalizar dashboards** según tus aplicaciones
2. **Configurar alertas** específicas para tu entorno
3. **Integrar Alertmanager** para notificaciones
4. **Añadir métricas custom** de tus aplicaciones
5. **Configurar backup** de configuraciones de Grafana

---

**💡 Tip**: Este stack está optimizado para clusters de producción. Para desarrollo, considera usar configuraciones más ligeras o herramientas como k9s para monitoreo básico.

**📊 Monitoreo**: Revisa regularmente el uso de recursos del stack de monitoreo y ajusta los límites según sea necesario.
