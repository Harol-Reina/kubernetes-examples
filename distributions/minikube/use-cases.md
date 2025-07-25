# Casos de Uso con Minikube

## Introducción

Este documento presenta varios casos de uso prácticos para trabajar con Kubernetes usando Minikube. Cada caso de uso incluye ejemplos completos con archivos YAML y comandos paso a paso.

## Tabla de Contenidos

1. [Despliegue de Aplicación Web Simple](#1-despliegue-de-aplicación-web-simple)
2. [Aplicación Multi-contenedor con Base de Datos](#2-aplicación-multi-contenedor-con-base-de-datos)
3. [Configuración con ConfigMaps y Secrets](#3-configuración-con-configmaps-y-secrets)
4. [Exposición de Servicios con Ingress](#4-exposición-de-servicios-con-ingress)
5. [Monitoreo y Logging](#5-monitoreo-y-logging)
6. [Desarrollo y Hot-Reload](#6-desarrollo-y-hot-reload)
7. [Jobs y CronJobs](#7-jobs-y-cronjobs)
8. [Almacenamiento Persistente](#8-almacenamiento-persistente)
9. [Autoescalado](#9-autoescalado)
10. [CI/CD con Minikube](#10-cicd-con-minikube)

---

## 1. Despliegue de Aplicación Web Simple

### Objetivo
Desplegar una aplicación web simple (nginx) y exponerla como servicio.

### Archivos necesarios
- `kubernetes-config/web-app/nginx-deployment.yaml`
- `kubernetes-config/web-app/nginx-service.yaml`

### Pasos

1. **Aplicar los manifiestos:**
```bash
kubectl apply -f kubernetes-config/web-app/
```

2. **Verificar el despliegue:**
```bash
kubectl get deployments
kubectl get pods
kubectl get services
```

3. **Acceder a la aplicación:**
```bash
minikube service nginx-service
```

### Comandos útiles
```bash
# Ver logs de la aplicación
kubectl logs -l app=nginx

# Escalar la aplicación
kubectl scale deployment nginx-deployment --replicas=3

# Ver detalles del deployment
kubectl describe deployment nginx-deployment
```

---

## 2. Aplicación Multi-contenedor con Base de Datos

### Objetivo
Desplegar una aplicación web con base de datos MySQL, demostrando comunicación entre servicios.

### Archivos necesarios
- `kubernetes-config/webapp-db/mysql-deployment.yaml`
- `kubernetes-config/webapp-db/mysql-service.yaml`
- `kubernetes-config/webapp-db/webapp-deployment.yaml`
- `kubernetes-config/webapp-db/webapp-service.yaml`

### Pasos

1. **Desplegar MySQL primero:**
```bash
kubectl apply -f kubernetes-config/webapp-db/mysql-deployment.yaml
kubectl apply -f kubernetes-config/webapp-db/mysql-service.yaml
```

2. **Esperar a que MySQL esté listo:**
```bash
kubectl wait --for=condition=ready pod -l app=mysql --timeout=300s
```

3. **Desplegar la aplicación web:**
```bash
kubectl apply -f kubernetes-config/webapp-db/webapp-deployment.yaml
kubectl apply -f kubernetes-config/webapp-db/webapp-service.yaml
```

4. **Verificar conectividad:**
```bash
kubectl exec -it deployment/webapp -- nc -zv mysql-service 3306
```

---

## 3. Configuración con ConfigMaps y Secrets

### Objetivo
Gestionar configuración de aplicaciones usando ConfigMaps y Secrets.

### Archivos necesarios
- `kubernetes-config/config-demo/configmap.yaml`
- `kubernetes-config/config-demo/secret.yaml`
- `kubernetes-config/config-demo/app-deployment.yaml`

### Pasos

1. **Crear ConfigMap y Secret:**
```bash
# Desde archivos YAML
kubectl apply -f kubernetes-config/config-demo/configmap.yaml
kubectl apply -f kubernetes-config/config-demo/secret.yaml

# O desde línea de comandos
kubectl create configmap app-config --from-literal=database_url=mysql://localhost:3306/mydb
kubectl create secret generic app-secret --from-literal=api_key=mi-api-key-secreto
```

2. **Desplegar aplicación que usa la configuración:**
```bash
kubectl apply -f kubernetes-config/config-demo/app-deployment.yaml
```

3. **Verificar configuración dentro del pod:**
```bash
kubectl exec -it deployment/config-demo-app -- env | grep -E "DATABASE_URL|API_KEY"
```

---

## 4. Exposición de Servicios con Ingress

### Objetivo
Configurar Ingress para exponer múltiples servicios a través de un solo punto de entrada.

### Prerrequisitos
```bash
# Habilitar ingress addon
minikube addons enable ingress
```

### Archivos necesarios
- `kubernetes-config/ingress-demo/app1-deployment.yaml`
- `kubernetes-config/ingress-demo/app2-deployment.yaml`
- `kubernetes-config/ingress-demo/ingress.yaml`

### Pasos

1. **Desplegar aplicaciones:**
```bash
kubectl apply -f kubernetes-config/ingress-demo/app1-deployment.yaml
kubectl apply -f kubernetes-config/ingress-demo/app2-deployment.yaml
```

2. **Crear Ingress:**
```bash
kubectl apply -f kubernetes-config/ingress-demo/ingress.yaml
```

3. **Obtener IP del Ingress:**
```bash
kubectl get ingress
minikube ip
```

4. **Configurar hosts locales:**
```bash
echo "$(minikube ip) app1.local app2.local" | sudo tee -a /etc/hosts
```

5. **Probar acceso:**
```bash
curl http://app1.local
curl http://app2.local
```

---

## 5. Monitoreo y Logging

### Objetivo
Implementar monitoreo básico y recolección de logs.

### Prerrequisitos
```bash
# Habilitar métricas
minikube addons enable metrics-server
```

### Pasos

1. **Verificar métricas:**
```bash
kubectl top nodes
kubectl top pods
```

2. **Recolectar logs centralizados:**
```bash
# Logs de todos los pods
kubectl logs -l app=mi-app --all-containers=true

# Logs en tiempo real
kubectl logs -f deployment/mi-app
```

3. **Usar Dashboard para monitoreo visual:**
```bash
minikube dashboard
```

---

## 6. Desarrollo y Hot-Reload

### Objetivo
Configurar un entorno de desarrollo que permita hot-reload de código.

### Archivos necesarios
- `kubernetes-config/dev-env/dev-deployment.yaml`
- `kubernetes-config/dev-env/dev-service.yaml`

### Pasos

1. **Configurar Docker env:**
```bash
eval $(minikube docker-env)
```

2. **Construir imagen de desarrollo:**
```bash
docker build -t mi-app:dev .
```

3. **Desplegar en modo desarrollo:**
```bash
kubectl apply -f kubernetes-config/dev-env/
```

4. **Configurar port-forwarding:**
```bash
kubectl port-forward service/dev-service 8080:80
```

5. **Actualizar código y reconstruir:**
```bash
# Hacer cambios en el código
docker build -t mi-app:dev .
kubectl rollout restart deployment/dev-deployment
```

---

## 7. Jobs y CronJobs

### Objetivo
Ejecutar tareas batch y programadas.

### Archivos necesarios
- `kubernetes-config/jobs/backup-job.yaml`
- `kubernetes-config/jobs/cleanup-cronjob.yaml`

### Pasos

1. **Ejecutar un Job una vez:**
```bash
kubectl apply -f kubernetes-config/jobs/backup-job.yaml
kubectl wait --for=condition=complete job/backup-job --timeout=300s
```

2. **Crear CronJob para tareas programadas:**
```bash
kubectl apply -f kubernetes-config/jobs/cleanup-cronjob.yaml
```

3. **Monitorear Jobs:**
```bash
kubectl get jobs
kubectl get cronjobs
kubectl logs job/backup-job
```

---

## 8. Almacenamiento Persistente

### Objetivo
Trabajar con volúmenes persistentes para datos que deben sobrevivir reinicios de pods.

### Archivos necesarios
- `kubernetes-config/storage/persistent-volume.yaml`
- `kubernetes-config/storage/persistent-volume-claim.yaml`
- `kubernetes-config/storage/pod-with-storage.yaml`

### Pasos

1. **Crear PersistentVolume y PersistentVolumeClaim:**
```bash
kubectl apply -f kubernetes-config/storage/persistent-volume.yaml
kubectl apply -f kubernetes-config/storage/persistent-volume-claim.yaml
```

2. **Verificar estado:**
```bash
kubectl get pv
kubectl get pvc
```

3. **Desplegar pod que usa el volumen:**
```bash
kubectl apply -f kubernetes-config/storage/pod-with-storage.yaml
```

4. **Probar persistencia:**
```bash
# Escribir datos
kubectl exec -it storage-pod -- echo "Datos persistentes" > /data/test.txt

# Eliminar y recrear pod
kubectl delete pod storage-pod
kubectl apply -f kubernetes-config/storage/pod-with-storage.yaml

# Verificar datos
kubectl exec -it storage-pod -- cat /data/test.txt
```

---

## 9. Autoescalado

### Objetivo
Configurar Horizontal Pod Autoscaler (HPA) para escalar automáticamente.

### Prerrequisitos
```bash
minikube addons enable metrics-server
```

### Archivos necesarios
- `kubernetes-config/autoscaling/app-deployment.yaml`
- `kubernetes-config/autoscaling/hpa.yaml`

### Pasos

1. **Desplegar aplicación con resource limits:**
```bash
kubectl apply -f kubernetes-config/autoscaling/app-deployment.yaml
```

2. **Crear HPA:**
```bash
kubectl apply -f kubernetes-config/autoscaling/hpa.yaml
# O desde línea de comandos:
kubectl autoscale deployment autoscale-demo --cpu-percent=50 --min=1 --max=10
```

3. **Generar carga para probar:**
```bash
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh
# Dentro del pod:
while true; do wget -q -O- http://autoscale-demo-service/; done
```

4. **Monitorear escalado:**
```bash
kubectl get hpa
kubectl get pods -w
```

---

## 10. CI/CD con Minikube

### Objetivo
Configurar un pipeline básico de CI/CD usando Minikube como entorno de testing.

### Script de CI/CD (`ci-cd-pipeline.sh`)

```bash
#!/bin/bash

# Script básico de CI/CD para Minikube

set -e

echo "🚀 Iniciando pipeline CI/CD..."

# 1. Configurar entorno
echo "📦 Configurando entorno Docker..."
eval $(minikube docker-env)

# 2. Construir imagen
echo "🏗️  Construyendo imagen..."
docker build -t mi-app:${BUILD_NUMBER:-latest} .

# 3. Ejecutar tests
echo "🧪 Ejecutando tests..."
docker run --rm mi-app:${BUILD_NUMBER:-latest} npm test

# 4. Desplegar a testing
echo "🚀 Desplegando a entorno de testing..."
envsubst < kubernetes-config/ci-cd/deployment-template.yaml | kubectl apply -f -

# 5. Ejecutar tests de integración
echo "🔍 Ejecutando tests de integración..."
kubectl wait --for=condition=ready pod -l app=mi-app --timeout=300s
kubectl port-forward service/mi-app-service 8080:80 &
sleep 5
curl -f http://localhost:8080/health || exit 1

# 6. Promover a producción (si es rama main)
if [ "$GIT_BRANCH" = "main" ]; then
    echo "🎯 Promoviendo a producción..."
    kubectl set image deployment/mi-app-prod app=mi-app:${BUILD_NUMBER:-latest}
fi

echo "✅ Pipeline completado exitosamente!"
```

### Archivos necesarios
- `kubernetes-config/ci-cd/deployment-template.yaml`
- `kubernetes-config/ci-cd/test-deployment.yaml`
- `kubernetes-config/ci-cd/prod-deployment.yaml`

---

## Comandos de Utilidad General

### Debug y Troubleshooting

```bash
# Describir recursos para obtener eventos
kubectl describe pod <nombre-pod>
kubectl describe deployment <nombre-deployment>

# Ver logs con timestamps
kubectl logs <nombre-pod> --timestamps

# Ejecutar comandos dentro de pods
kubectl exec -it <nombre-pod> -- /bin/bash

# Port forwarding para acceso local
kubectl port-forward pod/<nombre-pod> 8080:80

# Verificar conectividad de red
kubectl exec -it <nombre-pod> -- nslookup <nombre-servicio>

# Ver eventos del cluster
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Gestión de Recursos

```bash
# Ver uso de recursos
kubectl top nodes
kubectl top pods

# Ver todas las imágenes en uso
kubectl get pods -o jsonpath="{..image}" | tr -s '[[:space:]]' '\n' | sort | uniq

# Limpiar recursos no utilizados
kubectl delete pods --field-selector=status.phase=Succeeded
kubectl delete pods --field-selector=status.phase=Failed

# Backup de configuración
kubectl get all -o yaml > cluster-backup.yaml
```

### Consejos de Rendimiento

1. **Asignar recursos adecuados a Minikube:**
```bash
minikube start --cpus=4 --memory=8192 --disk-size=50gb
```

2. **Usar cache de imágenes Docker:**
```bash
minikube cache add <imagen>
```

3. **Precargar imágenes comunes:**
```bash
minikube ssh docker pull nginx:latest
minikube ssh docker pull mysql:8.0
```

4. **Configurar registry local:**
```bash
minikube addons enable registry
```

## Recursos y Referencias

- [Documentación oficial de Kubernetes](https://kubernetes.io/docs/)
- [Ejemplos de Kubernetes](https://github.com/kubernetes/examples)
- [Minikube Handbook](https://minikube.sigs.k8s.io/docs/handbook/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## Próximos Pasos

Después de trabajar con estos casos de uso, considera explorar:

1. **Helm** para gestión de paquetes de Kubernetes
2. **Kustomize** para personalización de manifiestos
3. **Istio** para service mesh
4. **ArgoCD** para GitOps
5. **Prometheus + Grafana** para monitoreo avanzado
