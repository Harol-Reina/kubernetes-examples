# Ejemplos para Producción

Esta carpeta contiene ejemplos de configuraciones listas para producción que incluyen alta disponibilidad, monitoreo, logging, seguridad y mejores prácticas.

## 📋 Contenido

### 1. Alta Disponibilidad
- **ha-deployment.yaml**: Deployment con alta disponibilidad, anti-affinity, health checks y sidecar de logging
- **app-deployment.yaml**: Deployment básico para autoscaling

### 2. Autoscaling
- **hpa.yaml**: Horizontal Pod Autoscaler con métricas de CPU y memoria

### 3. Seguridad
- **security-network-policies.yaml**: Políticas de red para micro-segmentación
  - Política para aplicación web
  - Política para base de datos
  - Política deny-all por defecto

### 4. Recursos y Límites
- **resource-quotas.yaml**: Configuración completa de recursos para namespace de producción
  - ResourceQuota para límites de recursos
  - LimitRange para valores por defecto
  - PodDisruptionBudget para alta disponibilidad

## 🎯 Configuraciones Enterprise Incluidas

### Deployment de Alta Disponibilidad
Configuración completa para aplicaciones críticas:
- **5 réplicas** distribuidas en diferentes nodos
- **Anti-affinity** para evitar single points of failure
- **Rolling updates** con estrategia controlada
- **Health checks** robustos (liveness + readiness probes)
- **Resource limits** apropiados para producción
- **Sidecar container** para logging distribuido
- **Tolerancias** a fallos de nodos
- **Variables de entorno** desde ConfigMaps y Secrets

### Autoscaling Inteligente
HPA configurado para escalado automático:
- Métricas de **CPU al 70%**
- Métricas de **memoria al 80%**
- Comportamiento controlado de scale-up/down
- Rango de **3-10 réplicas**

### Micro-segmentación de Red
Network Policies para aislamiento:
- **Deny-all por defecto** para seguridad máxima
- Políticas específicas para cada tier (web, database)
- Control granular de tráfico ingress/egress
- Aislamiento entre namespaces

### Gestión de Recursos
Governance completa de recursos:
- **Quotas de namespace** para control de costos
- **Límites por defecto** para contenedores
- **PodDisruptionBudgets** para disponibilidad
- Límites de **almacenamiento y objetos**

## 🚀 Cómo usar estos ejemplos

```bash
# Aplicar configuraciones por categoría en orden
kubectl apply -f "3. Seguridad/"
kubectl apply -f "4. Recursos y Límites/"
kubectl apply -f "1. Alta Disponibilidad/"
kubectl apply -f "2. Autoscaling/"

# Aplicar un ejemplo específico
kubectl apply -f "1. Alta Disponibilidad/ha-deployment.yaml"

# Ver estado de configuraciones de producción
kubectl get networkpolicies,resourcequotas,hpa,poddisruptionbudgets
kubectl get pods -o wide

# Verificar políticas de seguridad
kubectl describe networkpolicy
kubectl describe resourcequota

# Monitorear autoscaling
kubectl get hpa --watch
```

## 📝 Notas de Producción

### Seguridad
- Usar RBAC para control de acceso granular
- Implementar Network Policies para aislamiento
- Configurar Pod Security Standards
- Usar secrets para credenciales sensibles

### Alta Disponibilidad
- Múltiples réplicas distribuidas en diferentes nodos
- Affinity/Anti-affinity para distribución de pods
- Health checks robustos (liveness/readiness probes)
- Tolerancias a fallos de nodos

### Monitoreo
- Métricas de aplicación y sistema
- Alertas proactivas para problemas
- Dashboards para visibilidad operacional
- Logs centralizados para debugging

### Performance
- Resource requests y limits apropiados
- Autoescalado basado en métricas
- Node affinity para workloads específicos
- Optimización de storage y networking
