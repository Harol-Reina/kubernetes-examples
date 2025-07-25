# Ejemplos Básicos de Kubernetes

Esta carpeta contiene ejemplos fundamentales de Kubernetes que son esenciales para entender los conceptos básicos de orquestación de contenedores.

## 📋 Contenido

### 1. Pods
Conceptos fundamentales de Pods - la unidad básica de despliegue en Kubernetes:
- **pod-simple.yaml**: Pod básico con un solo contenedor
- **pod-multi-container.yaml**: Pod con múltiples contenedores

### 2. Services
Servicios básicos para exposición y descubrimiento:
- **service-clusterip.yaml**: Servicio interno del cluster
- **nginx-service.yaml**: Servicio para aplicación nginx

### 3. Deployments
Deployments básicos para gestión declarativa de aplicaciones:
- **deployment-basic.yaml**: Deployment básico con nginx
- **nginx-deployment.yaml**: Deployment de nginx con configuración completa
- **dev-deployment.yaml**: Deployment para ambiente de desarrollo

### 4. Services para Deployments
Servicios específicos para conectar con deployments:
- **dev-service.yaml**: Servicio para ambiente de desarrollo

### 5. ReplicaSets
ReplicaSets para control directo de réplicas:
- **replicaset-basic.yaml**: ReplicaSet básico

## 🎯 Ejemplos Incluidos

### Aplicación Web Simple
Conjunto de archivos que demuestran una aplicación web básica:
- `nginx-deployment.yaml` + `nginx-service.yaml`: Aplicación nginx completa

### Ambiente de Desarrollo
Configuración básica para desarrollo:
- `dev-deployment.yaml` + `dev-service.yaml`: Setup de desarrollo

## 🚀 Cómo usar estos ejemplos

```bash
# Aplicar ejemplos por categoría
kubectl apply -f "1. Pods/"
kubectl apply -f "2. Services/"
kubectl apply -f "3. Deployments/"

# Aplicar un ejemplo específico
kubectl apply -f "1. Pods/pod-simple.yaml"

# Aplicar todos los ejemplos básicos
find . -name "*.yaml" -exec kubectl apply -f {} \;

# Ver el estado de los recursos
kubectl get pods,services,deployments,replicasets

# Limpiar recursos
find . -name "*.yaml" -exec kubectl delete -f {} \;
```

## 📝 Notas

- Estos ejemplos funcionan en cualquier distribución de Kubernetes
- Son ideales para aprender los conceptos fundamentales
- Pueden servir como plantillas para tus propias aplicaciones
