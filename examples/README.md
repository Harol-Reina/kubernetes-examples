# Ejemplos de Kubernetes - Configuraciones Genéricas

Este directorio contiene ejemplos prácticos de configuraciones de Kubernetes que funcionan en cualquier distribución (Minikube, Kind, k3s, kubeadm, EKS, GKE, AKS, etc.).

## 📁 Estructura de Ejemplos

```
examples/
├── README.md                     # Este archivo
├── basic/                        # Ejemplos básicos de Kubernetes
│   ├── README.md                # Guía de ejemplos básicos
│   ├── 1. Pods/                 # Conceptos básicos de Pods
│   │   ├── pod-simple.yaml      # Pod básico
│   │   └── pod-multi-container.yaml # Pod con múltiples contenedores
│   ├── 2. Services/             # Servicios básicos
│   │   ├── service-clusterip.yaml # Servicio ClusterIP
│   │   └── nginx-service.yaml   # Servicio para nginx
│   ├── 3. Deployments/          # Deployments básicos
│   │   ├── deployment-basic.yaml # Deployment básico
│   │   ├── nginx-deployment.yaml # Deployment de nginx
│   │   └── dev-deployment.yaml  # Deployment para desarrollo
│   ├── 4. Services para Deployments/ # Servicios para deployments
│   │   └── dev-service.yaml     # Servicio para desarrollo
│   └── 5. ReplicaSets/          # ReplicaSets básicos
│       └── replicaset-basic.yaml # ReplicaSet básico
├── intermediate/                 # Ejemplos intermedios
│   ├── README.md                # Guía de ejemplos intermedios
│   ├── 1. Ingress/              # Ingress y routing
│   │   ├── ingress-basic.yaml   # Ingress básico
│   │   └── ingress.yaml         # Ingress avanzado
│   ├── 2. ConfigMaps/           # Configuración externalizada
│   │   ├── configmap.yaml       # ConfigMap básico
│   │   ├── configmap-env.yaml   # ConfigMap completo
│   │   └── app-deployment.yaml  # App con ConfigMap
│   ├── 3. Secrets/              # Gestión de secretos
│   │   ├── secret.yaml          # Secret básico
│   │   └── secret-generic.yaml  # Secrets genéricos
│   ├── 4. Volumes y Storage/    # Persistencia y almacenamiento
│   │   ├── persistent-volume.yaml # Persistent Volume
│   │   ├── persistent-volume-claim.yaml # PVC independiente
│   │   ├── pod-with-storage.yaml # Pod con storage
│   │   └── volume-pvc.yaml      # PVC con deployment
│   ├── 5. Aplicaciones Multi-contenedor/ # Apps complejas
│   │   ├── mysql-deployment.yaml # Base de datos MySQL
│   │   ├── mysql-service.yaml   # Servicio MySQL
│   │   ├── webapp-deployment.yaml # Aplicación web
│   │   ├── webapp-service.yaml  # Servicio web app
│   │   ├── app1-deployment.yaml # App 1 para Ingress
│   │   └── app2-deployment.yaml # App 2 para Ingress
│   ├── 6. Múltiples Aplicaciones con Ingress/ # Routing avanzado
│   └── 7. Monitoreo Básico/     # Stack ligero Prometheus-Grafana
│       ├── README.md            # Guía de monitoreo para bare metal
│       ├── prometheus/
│       │   ├── prometheus-config.yaml # Configuración optimizada
│       │   ├── prometheus-deployment.yaml # Deployment ligero
│       │   ├── prometheus-service.yaml # Servicio básico
│       │   └── prometheus-rbac.yaml # RBAC mínimo
│       ├── grafana/
│       │   ├── grafana-deployment.yaml # Deployment básico
│       │   ├── grafana-service.yaml # Servicio ClusterIP
│       │   └── grafana-configmap.yaml # Dashboards esenciales
│       ├── node-exporter/
│       │   └── node-exporter-daemonset.yaml # Node metrics ligero
│       └── monitoring-stack.yaml # Deploy todo-en-uno
├── advanced/                     # Ejemplos avanzados
│   ├── README.md                # Guía de ejemplos avanzados
│   ├── 1. StatefulSets/         # Aplicaciones con estado
│   │   └── statefulset-database.yaml # StatefulSet PostgreSQL
│   ├── 2. DaemonSets/           # Servicios de sistema
│   │   └── daemonset-logging.yaml # DaemonSet Fluentd
│   ├── 3. Jobs/                 # Tareas por lotes
│   │   ├── job-parallel.yaml    # Job con paralelismo
│   │   └── backup-job.yaml      # Job de backup
│   └── 4. CronJobs/             # Tareas programadas
│       ├── cronjob-backup.yaml  # CronJob backup avanzado
│       └── cleanup-cronjob.yaml # CronJob de limpieza
└── production/                   # Configuraciones de producción
    ├── README.md                # Guía de configuraciones de producción
    ├── 1. Alta Disponibilidad/  # HA y resiliencia
    │   ├── ha-deployment.yaml   # Deployment de alta disponibilidad
    │   └── app-deployment.yaml  # Deployment para autoscaling
    ├── 2. Autoscaling/          # Escalado automático
    │   └── hpa.yaml             # Horizontal Pod Autoscaler
    ├── 3. Seguridad/            # Políticas de seguridad
    │   └── security-network-policies.yaml # Políticas de red
    ├── 4. Recursos y Límites/   # Gestión de recursos
    │   └── resource-quotas.yaml # Cuotas y límites de recursos
    └── 5. Monitoreo/            # Stack de observabilidad
        ├── README.md            # Guía completa de monitoreo
        ├── prometheus/
        │   ├── prometheus-config.yaml # ConfigMap con configuración
        │   ├── prometheus-deployment.yaml # Deployment de Prometheus
        │   ├── prometheus-service.yaml # Servicio de Prometheus
        │   └── prometheus-rbac.yaml # RBAC para scraping
        ├── grafana/
        │   ├── grafana-deployment.yaml # Deployment de Grafana
        │   ├── grafana-service.yaml # Servicio de Grafana
        │   ├── grafana-configmap.yaml # Dashboards preconfigured
        │   └── grafana-pvc.yaml # Persistencia para dashboards
        ├── node-exporter/
        │   └── node-exporter-daemonset.yaml # Node metrics
        ├── kube-state-metrics/
        │   └── kube-state-metrics.yaml # K8s cluster metrics
        └── monitoring-stack.yaml # Deploy completo todo-en-uno
```

## 🎯 Categorías de Ejemplos

### 📚 Basic (Conceptos Fundamentales)
Ejemplos esenciales para entender los building blocks de Kubernetes:
- **Pods**: Unidad básica de despliegue
- **Services**: Exposición y descubrimiento de servicios
- **Deployments**: Gestión declarativa de aplicaciones
- **ReplicaSets**: Control de réplicas de pods

### 🔧 Intermediate (Configuración y Persistencia)
Ejemplos para aplicaciones más robustas y configurables:
- **Ingress**: Routing HTTP/HTTPS y terminación TLS
- **ConfigMaps**: Configuración externalizada
- **Secrets**: Gestión segura de credenciales
- **Volumes**: Persistencia y compartición de datos

### ⚡ Advanced (Workloads Especializados)
Ejemplos para casos de uso específicos y aplicaciones complejas:
- **StatefulSets**: Aplicaciones con estado y identidad persistente
- **DaemonSets**: Servicios de sistema que corren en cada nodo
- **Jobs**: Tareas de procesamiento por lotes
- **CronJobs**: Tareas programadas y mantenimiento

### 🏭 Production (Lista para Producción)
Configuraciones enterprise con alta disponibilidad, seguridad y monitoreo:
- **Alta Disponibilidad**: Multi-zona, anti-affinity, health checks
- **Seguridad**: Network policies, RBAC, Pod Security Standards
- **Monitoreo**: Prometheus, Grafana, alertas
- **Recursos**: Quotas, limits, autoscaling

## 🎯 Compatibilidad

Todos los ejemplos en este directorio están diseñados para ser **agnósticos a la distribución**, lo que significa que:

- ✅ Funcionan en **cualquier cluster** de Kubernetes v1.24+
- ✅ No dependen de características específicas de proveedores
- ✅ Usan recursos estándar de Kubernetes
- ✅ Son fácilmente adaptables a diferentes entornos

## 🚀 Cómo Usar los Ejemplos

### 1. Navegación por Categorías
```bash
# Ver todas las categorías disponibles
ls -la examples/

# Explorar ejemplos básicos
ls -la examples/basic/

# Ver ejemplos de una categoría específica
ls -la examples/intermediate/
```

### 2. Aplicar Ejemplos por Subcarpetas
```bash
# Aplicar todos los pods básicos
kubectl apply -f examples/basic/"1. Pods/"

# Aplicar configuraciones de Ingress
kubectl apply -f examples/intermediate/"1. Ingress/"

# Aplicar configuraciones de producción específicas
kubectl apply -f examples/production/"3. Seguridad/"
```

### 3. Aplicar Categorías Completas
```bash
# Aplicar todos los ejemplos básicos
find examples/basic/ -name "*.yaml" -exec kubectl apply -f {} \;

# Aplicar ejemplos intermedios
find examples/intermediate/ -name "*.yaml" -exec kubectl apply -f {} \;

# Aplicar configuraciones de producción
find examples/production/ -name "*.yaml" -exec kubectl apply -f {} \;
```

### 4. Progresión de Aprendizaje Recomendada
```bash
# 1. Empezar con conceptos básicos
kubectl apply -f examples/basic/"1. Pods/"
kubectl apply -f examples/basic/"2. Services/"
kubectl apply -f examples/basic/"3. Deployments/"

# 2. Avanzar a configuraciones intermedias
kubectl apply -f examples/intermediate/"2. ConfigMaps/"
kubectl apply -f examples/intermediate/"3. Secrets/"
kubectl apply -f examples/intermediate/"1. Ingress/"

# 3. Explorar workloads avanzados
kubectl apply -f examples/advanced/"1. StatefulSets/"
kubectl apply -f examples/advanced/"3. Jobs/"

# 4. Implementar configuraciones de producción
kubectl apply -f examples/production/"3. Seguridad/"
kubectl apply -f examples/production/"1. Alta Disponibilidad/"
```

## 📚 Estructura Detallada de Contenidos

### 📚 Basic/ - Fundamentos (9 archivos)
Conceptos esenciales para empezar con Kubernetes:
- **1. Pods/**: Pod simple y multi-contenedor
- **2. Services/**: ClusterIP y servicios para nginx
- **3. Deployments/**: Deployments básicos y de desarrollo
- **4. Services para Deployments/**: Conexión de servicios
- **5. ReplicaSets/**: Control directo de réplicas

### 🔧 Intermediate/ - Configuraciones Robustas (25+ archivos)
Aplicaciones más complejas y configurables:
- **1. Ingress/**: Routing HTTP básico y avanzado
- **2. ConfigMaps/**: Configuración externalizada
- **3. Secrets/**: Gestión segura de credenciales
- **4. Volumes y Storage/**: Persistencia de datos
- **5. Aplicaciones Multi-contenedor/**: Stacks completos (MySQL + WebApp)
- **6. Múltiples Aplicaciones con Ingress/**: Routing complejo
- **7. Monitoreo Básico/**: Stack Prometheus-Grafana para bare metal

### ⚡ Advanced/ - Workloads Especializados (6 archivos)
Casos de uso específicos y aplicaciones complejas:
- **1. StatefulSets/**: PostgreSQL con estado persistente
- **2. DaemonSets/**: Fluentd para logging distribuido
- **3. Jobs/**: Procesamiento paralelo y backups
- **4. CronJobs/**: Tareas programadas y limpieza

### 🏭 Production/ - Enterprise Ready (15+ archivos)
Configuraciones listas para producción:
- **1. Alta Disponibilidad/**: Deployments resilientes
- **2. Autoscaling/**: HPA con métricas avanzadas
- **3. Seguridad/**: Network Policies y micro-segmentación
- **4. Recursos y Límites/**: ResourceQuotas y governance
- **5. Monitoreo/**: Stack Prometheus-Grafana completo

## ⭐ Características Destacadas

### 🎯 Progresión Educativa
- **Aprendizaje gradual**: De conceptos simples a configuraciones enterprise
- **Ejemplos prácticos**: Casos de uso reales y aplicables
- **Documentación completa**: README detallado en cada categoría

### 🛡️ Calidad Enterprise
- **Mejores prácticas**: Health checks, resource limits, security
- **Configuraciones robustas**: HA, autoscaling, monitoring
- **Compatibilidad universal**: Funciona en cualquier distribución K8s

### 🚀 Facilidad de Uso
- **Estructura organizada**: Categorías claras por complejidad
- **Comandos listos**: Scripts de ejemplo para cada categoría
- **Personalización sencilla**: Fácil adaptación a necesidades específicas

## 📖 Guías de Referencia Rápida

### 🎯 Para Principiantes
```bash
# Empezar con pods simples
kubectl apply -f examples/basic/"1. Pods/pod-simple.yaml"
kubectl get pods

# Avanzar a servicios
kubectl apply -f examples/basic/"2. Services/"
kubectl get services

# Probar tu primer deployment
kubectl apply -f examples/basic/"3. Deployments/deployment-basic.yaml"
kubectl get deployments
```

### 🔧 Para Desarrolladores
```bash
# ConfigMaps para configuración
kubectl apply -f examples/intermediate/"2. ConfigMaps/"

# Secrets para credenciales
kubectl apply -f examples/intermediate/"3. Secrets/"

# Stack completo con BD
kubectl apply -f examples/intermediate/"5. Aplicaciones Multi-contenedor/"
```

### ⚡ Para DevOps
```bash
# StatefulSets para bases de datos
kubectl apply -f examples/advanced/"1. StatefulSets/"

# Jobs para tareas batch
kubectl apply -f examples/advanced/"3. Jobs/"

# Stack completo de monitoreo
kubectl apply -f examples/production/"5. Monitoreo/"

# Configuraciones de producción
kubectl apply -f examples/production/
```

## 🛠️ Comandos Útiles

### 📊 Monitoreo
```bash
# Ver todos los recursos por categoría
kubectl get all -n default

# Ver estado de workloads específicos
kubectl get pods,services,deployments
kubectl get statefulsets,daemonsets,jobs,cronjobs
kubectl get pv,pvc,configmaps,secrets

# Monitoreo en tiempo real
kubectl get pods --watch
kubectl get events --sort-by=.metadata.creationTimestamp
```

### 🧹 Limpieza
```bash
# Limpiar ejemplos por categoría
find examples/basic/ -name "*.yaml" -exec kubectl delete -f {} \;
find examples/intermediate/ -name "*.yaml" -exec kubectl delete -f {} \;
find examples/advanced/ -name "*.yaml" -exec kubectl delete -f {} \;
find examples/production/ -name "*.yaml" -exec kubectl delete -f {} \;

# Limpieza completa
kubectl delete all --all
kubectl delete pvc --all
kubectl delete configmaps --all
kubectl delete secrets --all
```

### 🔍 Debug y Troubleshooting
```bash
# Diagnosticar pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl logs -f deployment/<deployment-name>

# Acceso interactivo
kubectl exec -it <pod-name> -- /bin/bash

# Port forwarding para testing local
kubectl port-forward service/<service-name> 8080:80
```

## 📋 Requisitos del Sistema

### ✅ Clusters Compatibles
- **Minikube**: v1.24+ (desarrollo local)
- **Kind**: v1.24+ (testing con contenedores)
- **k3s**: v1.24+ (edge computing)
- **kubeadm**: v1.24+ (clusters personalizados)
- **EKS/GKE/AKS**: v1.24+ (clouds públicas)

### 💾 Recursos Recomendados
```bash
# Configuración mínima para desarrollo
minikube start --cpus=2 --memory=4096 --disk-size=20gb

# Configuración recomendada para todos los ejemplos
minikube start --cpus=4 --memory=8192 --disk-size=50gb

# Addons útiles para Minikube
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard
minikube addons enable registry
```

## 🚨 Solución de Problemas Comunes

### ImagePullBackOff
```bash
# Verificar que la imagen existe
kubectl describe pod <pod-name>

# Para Minikube, usar registro local
eval $(minikube docker-env)
docker images
```

### Pods en estado Pending
```bash
# Verificar recursos disponibles
kubectl describe nodes
kubectl top nodes

# Verificar eventos del pod
kubectl describe pod <pod-name>
```

### Servicios no accesibles
```bash
# Verificar endpoints
kubectl get endpoints <service-name>

# Verificar selectors y labels
kubectl get pods --show-labels
kubectl describe service <service-name>
```

### HPA no escala
```bash
# Verificar metrics-server
kubectl get pods -n kube-system | grep metrics-server

# Verificar métricas disponibles
kubectl top pods
kubectl describe hpa <hpa-name>
```

## 🤝 Contribuir

¿Quieres añadir nuevos ejemplos? Sigue estas pautas:

1. **Estructura**: Crear subcarpeta apropiada en la categoría correcta
2. **Calidad**: Incluir resource requests/limits y health checks
3. **Documentación**: Actualizar README correspondiente
4. **Testing**: Probar en cluster limpio
5. **Mejores prácticas**: Seguir estándares de seguridad y performance

## 📚 Referencias

- [Documentación Oficial de Kubernetes](https://kubernetes.io/docs/)
- [Guías de Minikube](https://minikube.sigs.k8s.io/docs/)
- [Ejemplos Oficiales de Kubernetes](https://github.com/kubernetes/examples)
- [Mejores Prácticas de Kubernetes](https://kubernetes.io/docs/concepts/configuration/overview/)
