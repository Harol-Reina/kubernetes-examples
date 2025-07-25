# Ejemplos Avanzados de Kubernetes

Esta carpeta contiene ejemplos de workloads especializados de Kubernetes para casos de uso específicos como aplicaciones con estado, tareas programadas y servicios de sistema.

## 📋 Contenido

### 1. StatefulSets
Aplicaciones con estado e identidad persistente:
- **statefulset-database.yaml**: Base de datos PostgreSQL con persistencia ordenada y servicio headless

### 2. DaemonSets
Servicios de sistema que corren en cada nodo:
- **daemonset-logging.yaml**: Agente de logging Fluentd en cada nodo con RBAC

### 3. Jobs
Tareas de procesamiento por lotes:
- **job-parallel.yaml**: Job con paralelismo y manejo de errores
- **backup-job.yaml**: Job de backup básico

### 4. CronJobs
Tareas programadas y mantenimiento automático:
- **cronjob-backup.yaml**: Backup programado de base de datos con limpieza automática
- **cleanup-cronjob.yaml**: Limpieza programada de recursos

## 🎯 Ejemplos Completos Incluidos

### Stack de Base de Datos con Estado
PostgreSQL con persistencia y alta disponibilidad:
- StatefulSet con 3 réplicas
- Servicio headless para comunicación directa
- Persistent Volume Claims automáticos
- Health checks robustos

### Sistema de Logging Distribuido
Fluentd corriendo en todos los nodos:
- DaemonSet con tolerancias para nodos master
- RBAC configurado (ServiceAccount, ClusterRole, ClusterRoleBinding)
- Configuración para envío a Elasticsearch
- Montaje de logs del host

### Procesamiento por Lotes
Jobs para tareas de procesamiento:
- Job paralelo con control de completions
- Manejo de errores y reintentos
- Variables de entorno para configuración

### Tareas Programadas
CronJobs para mantenimiento automático:
- Backup programado con retención
- Limpieza automática de recursos antiguos
- Notificaciones de estado

## 🚀 Cómo usar estos ejemplos

```bash
# Aplicar por categorías
kubectl apply -f "1. StatefulSets/"
kubectl apply -f "2. DaemonSets/"
kubectl apply -f "3. Jobs/"
kubectl apply -f "4. CronJobs/"

# Aplicar un ejemplo específico
kubectl apply -f "1. StatefulSets/statefulset-database.yaml"

# Ver estado de workloads avanzados
kubectl get statefulsets,daemonsets,jobs,cronjobs
kubectl get pods -o wide

# Monitorear jobs activos
kubectl get jobs --watch
kubectl logs job/<job-name>
```

## 📝 Notas

- **StatefulSets**: Mantienen identidad de red y almacenamiento persistente
- **DaemonSets**: Aseguran que un pod corra en cada nodo (o subset)
- **Jobs**: Ejecutan tareas hasta completarlas exitosamente
- **CronJobs**: Ejecutan Jobs en horarios programados (como cron)
- Estos workloads son ideales para aplicaciones especializadas
