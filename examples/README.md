# Ejemplos de Kubernetes - Configuraciones Genéricas

Este directorio contiene ejemplos prácticos de configuraciones de Kubernetes que funcionan en cualquier distribución (Minikube, Kind, k3s, kubeadm, EKS, GKE, AKS, etc.).

## 📁 Estructura de Ejemplos

```
examples/
├── README.md                 # Esta guía
├── web-app/                 # Aplicación web simple con nginx
├── webapp-db/               # Aplicación multi-contenedor con MySQL
├── config-demo/             # Demostración de ConfigMaps y Secrets
├── ingress-demo/            # Configuración de Ingress Controller
├── storage/                 # Volúmenes persistentes
├── jobs/                    # Jobs y CronJobs
├── autoscaling/             # Horizontal Pod Autoscaler (HPA)
├── dev-env/                 # Entorno de desarrollo
└── monitoring/              # Ejemplos de monitoreo básico
```

## 🎯 Compatibilidad

Todos los ejemplos en este directorio están diseñados para ser **agnósticos a la distribución**, lo que significa que:

- ✅ Funcionan en **cualquier cluster** de Kubernetes v1.24+
- ✅ No dependen de características específicas de proveedores
- ✅ Usan recursos estándar de Kubernetes
- ✅ Son fácilmente adaptables a diferentes entornos

## 🚀 Cómo Usar los Ejemplos

### 1. Navegación Rápida
```bash
# Ver todos los ejemplos disponibles
ls -la examples/

# Explorar un ejemplo específico
cd examples/web-app/
```

### 2. Aplicar un Ejemplo
```bash
# Aplicar configuración completa de un directorio
kubectl apply -f examples/web-app/

# Aplicar ejemplo específico
kubectl apply -f examples/web-app/deployment.yaml
```

### 3. Personalización
```bash
# Copiar ejemplo para personalizar
cp -r examples/web-app/ my-custom-app/
# Editar configuraciones según necesidades
```

## 📚 Ejemplos Incluidos

### 🌐 web-app/
Aplicación web simple con nginx ideal para aprender conceptos básicos.
- **Recursos**: Deployment, Service, ConfigMap
- **Casos de uso**: Primer contacto con Kubernetes, demos rápidas
- **Tiempo de setup**: 2 minutos

### 🏗️ webapp-db/
Aplicación completa con frontend, backend y base de datos.
- **Recursos**: Multiple Deployments, Services, PVC, Secrets
- **Casos de uso**: Aplicaciones reales, pruebas de arquitectura
- **Tiempo de setup**: 5 minutos

### ⚙️ config-demo/
Ejemplos de gestión de configuración y secretos.
- **Recursos**: ConfigMaps, Secrets, Environment Variables
- **Casos de uso**: Separación de código y configuración
- **Tiempo de setup**: 3 minutos

### 🌍 ingress-demo/
Configuraciones de acceso externo y balanceadores de carga.
- **Recursos**: Ingress, Services, TLS/SSL
- **Casos de uso**: Exposición de servicios, terminación SSL
- **Tiempo de setup**: 5 minutos (requiere Ingress Controller)

### 💾 storage/
Ejemplos de almacenamiento persistente y volúmenes.
- **Recursos**: PVC, PV, StorageClass, StatefulSets
- **Casos de uso**: Bases de datos, almacenamiento de archivos
- **Tiempo de setup**: 5 minutos

### ⏰ jobs/
Tareas programadas y trabajos batch.
- **Recursos**: Job, CronJob, Batch workloads
- **Casos de uso**: Tareas programadas, procesamiento batch
- **Tiempo de setup**: 3 minutos

### 📈 autoscaling/
Ejemplos de escalabilidad automática.
- **Recursos**: HPA, VPA, Metrics Server
- **Casos de uso**: Aplicaciones con carga variable
- **Tiempo de setup**: 5 minutos (requiere Metrics Server)

### 🛠️ dev-env/
Configuraciones optimizadas para desarrollo.
- **Recursos**: Development-friendly configs, Debug tools
- **Casos de uso**: Desarrollo local, debugging
- **Tiempo de setup**: 3 minutos

### 📊 monitoring/
Ejemplos básicos de monitoreo y observabilidad.
- **Recursos**: ServiceMonitor, Probes, Basic metrics
- **Casos de uso**: Monitoreo básico, health checks
- **Tiempo de setup**: 5 minutos

## Guía de Uso

### 1. Aplicación Web Simple (`web-app/`)

**Archivos:**
- `nginx-deployment.yaml` - Deployment de nginx con 2 réplicas
- `nginx-service.yaml` - Service tipo NodePort

**Desplegar:**
```bash
kubectl apply -f kubernetes-config/web-app/
```

**Acceder:**
```bash
minikube service nginx-service
```

**Características:**
- ✅ Resource requests/limits configurados
- ✅ Liveness y readiness probes
- ✅ Service tipo NodePort en puerto 30080

---

### 2. Aplicación con Base de Datos (`webapp-db/`)

**Archivos:**
- `mysql-deployment.yaml` - MySQL 8.0 con configuración básica
- `mysql-service.yaml` - Service interno para MySQL
- `webapp-deployment.yaml` - Aplicación PHP que conecta a MySQL
- `webapp-service.yaml` - Service + ConfigMap con código PHP

**Desplegar:**
```bash
# Primero MySQL
kubectl apply -f kubernetes-config/webapp-db/mysql-deployment.yaml
kubectl apply -f kubernetes-config/webapp-db/mysql-service.yaml

# Esperar a que MySQL esté listo
kubectl wait --for=condition=ready pod -l app=mysql --timeout=300s

# Luego la aplicación web
kubectl apply -f kubernetes-config/webapp-db/webapp-deployment.yaml
kubectl apply -f kubernetes-config/webapp-db/webapp-service.yaml
```

**Características:**
- ✅ Comunicación entre servicios
- ✅ Variables de entorno para configuración
- ✅ Código PHP que demuestra conexión a BD
- ✅ Contador de visitas en base de datos

---

### 3. ConfigMaps y Secrets (`config-demo/`)

**Archivos:**
- `configmap.yaml` - Configuración de aplicación y archivos
- `secret.yaml` - Información sensible codificada
- `app-deployment.yaml` - App que usa ConfigMaps y Secrets

**Desplegar:**
```bash
kubectl apply -f kubernetes-config/config-demo/
```

**Características:**
- ✅ Variables de entorno desde ConfigMap
- ✅ Variables de entorno desde Secret
- ✅ Archivos montados desde ConfigMap
- ✅ Página web que muestra la configuración

---

### 4. Ingress Controller (`ingress-demo/`)

**Prerrequisitos:**
```bash
minikube addons enable ingress
```

**Archivos:**
- `app1-deployment.yaml` - Primera aplicación con contenido personalizado
- `app2-deployment.yaml` - Segunda aplicación con API simulada
- `ingress.yaml` - Configuración de Ingress

**Desplegar:**
```bash
kubectl apply -f kubernetes-config/ingress-demo/

# Configurar hosts locales
echo "$(minikube ip) app1.local app2.local apps.local" | sudo tee -a /etc/hosts
```

**Acceder:**
```bash
curl http://app1.local
curl http://app2.local
curl http://apps.local/app1
curl http://apps.local/app2
```

**Características:**
- ✅ Enrutamiento basado en host
- ✅ Enrutamiento basado en path
- ✅ Múltiples aplicaciones en un solo Ingress

---

### 5. Almacenamiento Persistente (`storage/`)

**Archivos:**
- `persistent-volume.yaml` - PersistentVolume local
- `persistent-volume-claim.yaml` - PersistentVolumeClaim
- `pod-with-storage.yaml` - Pod y Deployment que usan el volumen

**Desplegar:**
```bash
kubectl apply -f kubernetes-config/storage/
```

**Probar persistencia:**
```bash
# Escribir datos
kubectl exec -it storage-pod -- echo "Datos persistentes" > /data/test.txt

# Eliminar y recrear pod
kubectl delete pod storage-pod
kubectl apply -f kubernetes-config/storage/pod-with-storage.yaml

# Verificar que los datos persisten
kubectl exec -it storage-pod -- cat /data/test.txt
```

**Características:**
- ✅ PersistentVolume con hostPath
- ✅ PersistentVolumeClaim
- ✅ Datos que sobreviven reinicios de pods

---

### 6. Jobs y CronJobs (`jobs/`)

**Archivos:**
- `backup-job.yaml` - Job simple y job paralelo
- `cleanup-cronjob.yaml` - CronJobs programados

**Desplegar:**
```bash
# Job único
kubectl apply -f kubernetes-config/jobs/backup-job.yaml

# CronJobs programados
kubectl apply -f kubernetes-config/jobs/cleanup-cronjob.yaml
```

**Monitorear:**
```bash
kubectl get jobs
kubectl get cronjobs
kubectl logs job/backup-job
```

**Características:**
- ✅ Job simple con simulación de backup
- ✅ Job paralelo con múltiples workers
- ✅ CronJob para limpieza programada
- ✅ Configuración de retry y timeouts

---

### 7. Autoescalado (`autoscaling/`)

**Prerrequisitos:**
```bash
minikube addons enable metrics-server
```

**Archivos:**
- `app-deployment.yaml` - Aplicación con resource requests definidos
- `hpa.yaml` - Horizontal Pod Autoscaler

**Desplegar:**
```bash
kubectl apply -f kubernetes-config/autoscaling/
```

**Generar carga:**
```bash
# Crear pod generador de carga
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh

# Dentro del pod:
while true; do wget -q -O- http://autoscale-demo-service/; done
```

**Monitorear:**
```bash
kubectl get hpa -w
kubectl get pods -l app=autoscale-demo -w
kubectl top pods
```

**Características:**
- ✅ HPA basado en CPU
- ✅ HPA basado en memoria
- ✅ Configuraciones de comportamiento de escalado
- ✅ Interfaz web para demostración

---

### 8. Entorno de Desarrollo (`dev-env/`)

**Archivos:**
- `dev-deployment.yaml` - Deployment con código Node.js
- `dev-service.yaml` - Service + scripts de desarrollo

**Desplegar:**
```bash
kubectl apply -f kubernetes-config/dev-env/
```

**Desarrollo con hot-reload:**
```bash
# Configurar Docker env
eval $(minikube docker-env)

# Construir imagen de desarrollo
docker build -t dev-app:latest .

# Port forwarding para desarrollo
kubectl port-forward service/dev-service 8080:3000
```

**Características:**
- ✅ Configuración para desarrollo local
- ✅ Scripts para hot-reload
- ✅ Servidor Node.js con API REST
- ✅ Variables de entorno para desarrollo

---

### 9. CI/CD (`ci-cd/`)

**Archivos:**
- `deployment-template.yaml` - Template con variables de entorno
- `test-deployment.yaml` - Deployment de testing + tests de integración
- `prod-deployment.yaml` - Deployment de producción con seguridad

**Usar con el script de CI/CD:**
```bash
# Hacer ejecutable el script
chmod +x ci-cd-pipeline.sh

# Ejecutar pipeline completo
./ci-cd-pipeline.sh

# Solo construcción
./ci-cd-pipeline.sh build

# Solo tests
./ci-cd-pipeline.sh test
```

**Características:**
- ✅ Pipeline automatizado
- ✅ Tests de integración
- ✅ Despliegue por entornos
- ✅ Configuraciones de seguridad para producción

---

## Comandos Útiles

### Limpieza General
```bash
# Eliminar todos los recursos de los ejemplos
kubectl delete deployments,services,ingress,jobs,cronjobs,hpa,pv,pvc --all

# Limpiar pods completados/fallidos
kubectl delete pods --field-selector=status.phase=Succeeded
kubectl delete pods --field-selector=status.phase=Failed
```

### Monitoreo
```bash
# Ver todos los recursos
kubectl get all

# Ver eventos del cluster
kubectl get events --sort-by=.metadata.creationTimestamp

# Ver uso de recursos
kubectl top nodes
kubectl top pods

# Logs en tiempo real
kubectl logs -f deployment/<nombre-deployment>
```

### Debug
```bash
# Describir recursos para ver eventos
kubectl describe pod <pod-name>
kubectl describe deployment <deployment-name>

# Shell interactivo en pod
kubectl exec -it <pod-name> -- /bin/sh

# Port forwarding para acceso local
kubectl port-forward pod/<pod-name> 8080:80
```

## Requisitos de Sistema

**Minikube mínimo:**
- CPU: 2 cores
- Memoria: 4GB
- Disco: 20GB

**Para todos los ejemplos:**
```bash
minikube start --cpus=4 --memory=8192 --disk-size=50gb
```

**Addons recomendados:**
```bash
minikube addons enable dashboard
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable registry
```

## Solución de Problemas

### ImagePullBackOff
```bash
# Verificar que la imagen existe en Minikube
eval $(minikube docker-env)
docker images

# Reconstruir imagen si es necesaria
docker build -t <image-name> .
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

# Verificar labels
kubectl get pods --show-labels
```

### HPA no funciona
```bash
# Verificar metrics-server
kubectl get pods -n kube-system | grep metrics-server

# Verificar métricas disponibles
kubectl top pods
kubectl describe hpa <hpa-name>
```

## Contribuir

Para añadir nuevos ejemplos:

1. Crear directorio en `kubernetes-config/`
2. Incluir manifiestos YAML válidos
3. Añadir resource requests/limits
4. Incluir probes de salud
5. Documentar en este README
6. Probar en Minikube limpio

## Referencias

- [Documentación de Kubernetes](https://kubernetes.io/docs/)
- [Guías de Minikube](https://minikube.sigs.k8s.io/docs/)
- [Ejemplos oficiales de Kubernetes](https://github.com/kubernetes/examples)
- [Mejores prácticas](https://kubernetes.io/docs/concepts/configuration/overview/)
