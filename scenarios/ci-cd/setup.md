# Configuración de CI/CD con Kubernetes

Este escenario demuestra cómo implementar pipelines de Integración Continua y Despliegue Continuo (CI/CD) usando Kubernetes como plataforma de orquestación.

## Tabla de Contenidos

1. [Introducción](#introducción)
2. [Prerrequisitos](#prerrequisitos)
3. [Arquitectura del Pipeline](#arquitectura-del-pipeline)
4. [Configuración del Entorno](#configuración-del-entorno)
5. [Implementación del Pipeline](#implementación-del-pipeline)
6. [Estrategias de Despliegue](#estrategias-de-despliegue)
7. [Monitoreo y Observabilidad](#monitoreo-y-observabilidad)
8. [Mejores Prácticas](#mejores-prácticas)
9. [Troubleshooting](#troubleshooting)

## Introducción

Los pipelines de CI/CD en Kubernetes permiten automatizar el proceso completo desde el código fuente hasta la producción, proporcionando:

- **Integración Continua**: Automatización de construcción y testing
- **Despliegue Continuo**: Automatización del despliegue en múltiples entornos
- **Rollbacks Automáticos**: Capacidad de revertir cambios problemáticos
- **Scaling Automático**: Ajuste de recursos según demanda
- **Observabilidad**: Monitoreo completo del pipeline

## Prerrequisitos

### Software Requerido

- **Kubernetes Cluster** (Minikube, Kind, EKS, GKE, AKS, etc.)
- **kubectl** configurado y conectado al cluster
- **Docker** para construcción de imágenes
- **Git** para control de versiones

### Herramientas Opcionales

- **Helm** para gestión de paquetes
- **ArgoCD** para GitOps
- **Jenkins/GitLab CI/GitHub Actions** para pipelines externos
- **Prometheus + Grafana** para monitoreo

### Verificación de Prerrequisitos

```bash
# Verificar conexión al cluster
kubectl cluster-info

# Verificar nodos disponibles
kubectl get nodes

# Verificar addons (si usas Minikube)
minikube addons list | grep enabled
```

## Arquitectura del Pipeline

### Flujo General

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌──────────────┐
│   Código    │───▶│   Build &    │───▶│   Testing   │───▶│  Despliegue  │
│   Fuente    │    │   Package    │    │ Integración │    │  Producción  │
└─────────────┘    └──────────────┘    └─────────────┘    └──────────────┘
       │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌──────────────┐
│ Git Webhook │    │ Docker Build │    │ Test Suite  │    │ Blue/Green   │
│ Trigger     │    │ + Registry   │    │ + Validation│    │ Deployment   │
└─────────────┘    └──────────────┘    └─────────────┘    └──────────────┘
```

### Entornos

1. **Development**: Desarrollo local y testing inicial
2. **Testing**: Testing automatizado e integración
3. **Staging**: Pre-producción para validación final
4. **Production**: Entorno productivo

## Configuración del Entorno

### 1. Estructura de Archivos

```
scenarios/ci-cd/
├── setup.md                           # Esta guía
├── ci-cd-pipeline.sh                  # Script principal del pipeline
├── kubernetes-config/                 # Configuraciones de Kubernetes
│   ├── deployment-template.yaml       # Template para deployments
│   ├── test-deployment.yaml          # Configuración para testing
│   └── prod-deployment.yaml          # Configuración para producción
└── use-cases.md                      # Casos de uso específicos
```

### 2. Configuración de Namespaces

```bash
# Crear namespaces para diferentes entornos
kubectl create namespace development
kubectl create namespace testing  
kubectl create namespace staging
kubectl create namespace production

# Configurar contextos (opcional)
kubectl config set-context dev --namespace=development
kubectl config set-context test --namespace=testing
kubectl config set-context staging --namespace=staging
kubectl config set-context prod --namespace=production
```

### 3. Configuración de RBAC

```bash
# Crear ServiceAccount para CI/CD
kubectl create serviceaccount ci-cd-bot -n default

# Aplicar permisos necesarios
kubectl create clusterrolebinding ci-cd-bot-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=default:ci-cd-bot
```

## Implementación del Pipeline

### 1. Script de Pipeline Automatizado

El archivo `ci-cd-pipeline.sh` proporciona un pipeline completo con las siguientes funciones:

```bash
# Hacer el script ejecutable
chmod +x ci-cd-pipeline.sh

# Ejecutar pipeline completo
./ci-cd-pipeline.sh

# Ejecutar solo construcción
./ci-cd-pipeline.sh build

# Ejecutar solo tests
./ci-cd-pipeline.sh test

# Ejecutar solo despliegue
./ci-cd-pipeline.sh deploy

# Hacer rollback
./ci-cd-pipeline.sh rollback

# Limpiar recursos
./ci-cd-pipeline.sh cleanup
```

### 2. Variables de Entorno

```bash
# Configuración básica
export APP_NAME="mi-aplicacion"
export BUILD_NUMBER="123"
export GIT_COMMIT="abc1234"
export GIT_BRANCH="main"

# Configuración avanzada
export DOCKER_REGISTRY="mi-registry.com"
export NAMESPACE="production"
export SKIP_CONFIRMATION="true"

# Ejecutar con configuración personalizada
BUILD_NUMBER=456 GIT_BRANCH=develop ./ci-cd-pipeline.sh
```

### 3. Integración con Git Hooks

```bash
#!/bin/bash
# .git/hooks/pre-push

echo "🚀 Ejecutando pipeline CI/CD antes del push..."

# Ejecutar tests locales
./scenarios/ci-cd/ci-cd-pipeline.sh test

if [ $? -eq 0 ]; then
    echo "✅ Tests pasaron, continuando con push..."
else
    echo "❌ Tests fallaron, cancelando push..."
    exit 1
fi
```

## Estrategias de Despliegue

### 1. Rolling Update (Por defecto)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mi-app
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

### 2. Blue-Green Deployment

```bash
# Desplegar nueva versión (Green)
kubectl apply -f kubernetes-config/prod-deployment.yaml

# Cambiar tráfico de Blue a Green
kubectl patch service mi-app-service -p '{"spec":{"selector":{"version":"green"}}}'

# Verificar y mantener o rollback
kubectl get pods -l version=green
```

### 3. Canary Deployment

```yaml
# Despliegue progresivo
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: mi-app-canary
spec:
  strategy:
    canary:
      steps:
      - setWeight: 10  # 10% del tráfico
      - pause: {duration: 30s}
      - setWeight: 50  # 50% del tráfico
      - pause: {duration: 30s}
      - setWeight: 100 # 100% del tráfico
```

## Monitoreo y Observabilidad

### 1. Health Checks

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 5
```

### 2. Métricas de Pipeline

```bash
# Ver estado de deployments
kubectl get deployments --all-namespaces

# Ver estado de pods
kubectl get pods --all-namespaces

# Ver logs de pipeline
kubectl logs -l app=ci-cd-pipeline

# Ver métricas de recursos
kubectl top pods
kubectl top nodes
```

### 3. Alertas y Notificaciones

```bash
# Webhook para notificaciones Slack
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"🚀 Despliegue completado en producción"}' \
  $SLACK_WEBHOOK_URL

# Integración con email
echo "Despliegue completado" | mail -s "CI/CD Status" admin@company.com
```

## Mejores Prácticas

### 1. Gestión de Secrets

```bash
# Crear secrets para credenciales
kubectl create secret generic registry-credentials \
  --from-literal=username=myuser \
  --from-literal=password=mypass

# Usar secrets en deployments
kubectl create secret docker-registry regcred \
  --docker-server=myregistry.com \
  --docker-username=myuser \
  --docker-password=mypass
```

### 2. Resource Limits

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### 3. Security Policies

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
    - ALL
```

### 4. Networking

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

## Integración con Herramientas Externas

### 1. Jenkins Integration

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                script {
                    sh './scenarios/ci-cd/ci-cd-pipeline.sh build'
                }
            }
        }
        
        stage('Test') {
            steps {
                script {
                    sh './scenarios/ci-cd/ci-cd-pipeline.sh test'
                }
            }
        }
        
        stage('Deploy') {
            steps {
                script {
                    sh './scenarios/ci-cd/ci-cd-pipeline.sh deploy'
                }
            }
        }
    }
}
```

### 2. GitHub Actions Integration

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup kubectl
      uses: azure/setup-kubectl@v1
      
    - name: Run CI/CD Pipeline
      run: |
        chmod +x ./scenarios/ci-cd/ci-cd-pipeline.sh
        ./scenarios/ci-cd/ci-cd-pipeline.sh
```

### 3. GitLab CI Integration

```yaml
stages:
  - build
  - test
  - deploy

variables:
  DOCKER_DRIVER: overlay2

build:
  stage: build
  script:
    - ./scenarios/ci-cd/ci-cd-pipeline.sh build

test:
  stage: test
  script:
    - ./scenarios/ci-cd/ci-cd-pipeline.sh test

deploy:
  stage: deploy
  script:
    - ./scenarios/ci-cd/ci-cd-pipeline.sh deploy
  only:
    - main
```

## Troubleshooting

### Problemas Comunes

#### 1. Pipeline Falla en Build

```bash
# Verificar Docker daemon
docker info

# Verificar permisos
docker ps

# Ver logs de construcción
docker build --no-cache -t test .
```

#### 2. Tests de Integración Fallan

```bash
# Verificar conectividad
kubectl get services
kubectl get endpoints

# Ver logs de tests
kubectl logs job/integration-tests

# Debug interactivo
kubectl run debug --image=busybox -it --rm -- /bin/sh
```

#### 3. Despliegue Falla

```bash
# Verificar recursos disponibles
kubectl describe nodes
kubectl top nodes

# Ver eventos del cluster
kubectl get events --sort-by=.metadata.creationTimestamp

# Verificar imágenes
kubectl describe pod <pod-name>
```

#### 4. Rollback No Funciona

```bash
# Ver historial de rollouts
kubectl rollout history deployment/mi-app

# Rollback manual a versión específica
kubectl rollout undo deployment/mi-app --to-revision=2

# Verificar estado
kubectl rollout status deployment/mi-app
```

### Comandos de Debug

```bash
# Estado general del cluster
kubectl get all --all-namespaces

# Información detallada de recursos
kubectl describe deployment <deployment-name>
kubectl describe pod <pod-name>
kubectl describe service <service-name>

# Logs y eventos
kubectl logs <pod-name> --previous
kubectl get events --field-selector involvedObject.name=<resource-name>

# Acceso interactivo a pods
kubectl exec -it <pod-name> -- /bin/sh

# Port forwarding para debug
kubectl port-forward <pod-name> 8080:3000
```

## Recursos Adicionales

- [Documentación oficial de Kubernetes](https://kubernetes.io/docs/)
- [Best Practices for CI/CD](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/)
- [GitOps con ArgoCD](https://argoproj.github.io/argo-cd/)
- [Helm Charts](https://helm.sh/docs/)
- [Prometheus Monitoring](https://prometheus.io/docs/)

## Próximos Pasos

1. **Implementar GitOps** con ArgoCD o Flux
2. **Agregar Security Scanning** con herramientas como Clair o Twistlock
3. **Implementar Feature Flags** para despliegues más seguros
4. **Configurar Multi-cluster** para alta disponibilidad
5. **Agregar Testing de Performance** automático
