# Casos de Uso de CI/CD con Kubernetes

Este documento presenta casos de uso prácticos para implementar pipelines de CI/CD en Kubernetes, desde configuraciones básicas hasta implementaciones avanzadas en entornos empresariales.

## Tabla de Contenidos

1. [Pipeline Básico para Aplicación Web](#1-pipeline-básico-para-aplicación-web)
2. [Pipeline Multi-entorno (Dev/Staging/Prod)](#2-pipeline-multi-entorno)
3. [Pipeline con Microservicios](#3-pipeline-con-microservicios)
4. [Pipeline con Testing Automático](#4-pipeline-con-testing-automático)
5. [Pipeline con Blue-Green Deployment](#5-pipeline-con-blue-green-deployment)
6. [Pipeline con Canary Deployment](#6-pipeline-con-canary-deployment)
7. [Pipeline GitOps con ArgoCD](#7-pipeline-gitops-con-argocd)
8. [Pipeline con Security Scanning](#8-pipeline-con-security-scanning)
9. [Pipeline Multi-cluster](#9-pipeline-multi-cluster)
10. [Pipeline para Aplicaciones Serverless](#10-pipeline-para-aplicaciones-serverless)

---

## 1. Pipeline Básico para Aplicación Web

### Objetivo
Implementar un pipeline simple que construya, pruebe y despliegue una aplicación web Node.js.

### Estructura del Proyecto
```
mi-webapp/
├── src/
│   ├── app.js
│   └── routes/
├── tests/
│   └── app.test.js
├── Dockerfile
├── package.json
└── .github/workflows/ci-cd.yml
```

### Configuración

#### 1. Dockerfile
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
USER node
CMD ["npm", "start"]
```

#### 2. Pipeline Script
```bash
#!/bin/bash
# Uso del script principal
APP_NAME="mi-webapp" ./ci-cd-pipeline.sh
```

#### 3. Deployment YAML
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mi-webapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: mi-webapp
  template:
    metadata:
      labels:
        app: mi-webapp
    spec:
      containers:
      - name: webapp
        image: mi-webapp:${BUILD_NUMBER}
        ports:
        - containerPort: 3000
        resources:
          requests:
            memory: "128Mi"
            cpu: "250m"
          limits:
            memory: "256Mi"
            cpu: "500m"
```

### Comandos de Ejecución
```bash
# Ejecutar pipeline completo
./ci-cd-pipeline.sh

# Solo construcción y test
./ci-cd-pipeline.sh build
./ci-cd-pipeline.sh test

# Monitorear despliegue
kubectl rollout status deployment/mi-webapp
kubectl get pods -l app=mi-webapp
```

---

## 2. Pipeline Multi-entorno

### Objetivo
Gestionar despliegues automáticos en múltiples entornos (development, staging, production) basados en ramas de Git.

### Estrategia de Ramas
- `feature/*` → Development
- `develop` → Staging  
- `main` → Production

### Configuración por Entorno

#### Development
```bash
export ENVIRONMENT="development"
export REPLICAS=1
export SERVICE_TYPE="ClusterIP"
export NAMESPACE="dev"
```

#### Staging
```bash
export ENVIRONMENT="staging"
export REPLICAS=2
export SERVICE_TYPE="NodePort"
export NAMESPACE="staging"
```

#### Production
```bash
export ENVIRONMENT="production"
export REPLICAS=5
export SERVICE_TYPE="LoadBalancer"
export NAMESPACE="prod"
```

### Script de Automatización
```bash
#!/bin/bash

# Determinar entorno basado en rama
case "$GIT_BRANCH" in
  "main")
    ENVIRONMENT="production"
    NAMESPACE="prod"
    REPLICAS=5
    ;;
  "develop")
    ENVIRONMENT="staging"
    NAMESPACE="staging"
    REPLICAS=2
    ;;
  *)
    ENVIRONMENT="development"
    NAMESPACE="dev"
    REPLICAS=1
    ;;
esac

# Ejecutar pipeline
ENVIRONMENT=$ENVIRONMENT NAMESPACE=$NAMESPACE REPLICAS=$REPLICAS ./ci-cd-pipeline.sh
```

---

## 3. Pipeline con Microservicios

### Objetivo
Orquestar el despliegue de múltiples microservicios con dependencias entre ellos.

### Arquitectura
```
Frontend (React) → API Gateway → Auth Service
                              → User Service  
                              → Order Service → Database
```

### Configuración

#### 1. Pipeline Maestro
```bash
#!/bin/bash
# deploy-microservices.sh

SERVICES=("auth-service" "user-service" "order-service" "api-gateway" "frontend")

for service in "${SERVICES[@]}"; do
    echo "🚀 Desplegando $service..."
    
    cd $service
    APP_NAME=$service ../ci-cd-pipeline.sh
    
    # Esperar a que esté listo antes del siguiente
    kubectl wait --for=condition=ready pod -l app=$service --timeout=300s
    cd ..
done

echo "✅ Todos los microservicios desplegados"
```

#### 2. Dependency Management
```yaml
# auth-service dependency check
apiVersion: batch/v1
kind: Job
metadata:
  name: auth-service-migration
spec:
  template:
    spec:
      containers:
      - name: migration
        image: auth-service:${BUILD_NUMBER}
        command: ["npm", "run", "migrate"]
      restartPolicy: Never
```

#### 3. Service Mesh (Istio)
```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: microservices-routing
spec:
  hosts:
  - api.mycompany.com
  http:
  - match:
    - uri:
        prefix: "/auth"
    route:
    - destination:
        host: auth-service
  - match:
    - uri:
        prefix: "/users"
    route:
    - destination:
        host: user-service
```

---

## 4. Pipeline con Testing Automático

### Objetivo
Implementar una suite completa de testing automatizado en el pipeline.

### Tipos de Tests

#### 1. Unit Tests
```bash
# En el pipeline
run_unit_tests() {
    log_info "🧪 Ejecutando tests unitarios..."
    docker run --rm $IMAGE_TAG npm test -- --coverage
}
```

#### 2. Integration Tests
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: integration-tests
spec:
  template:
    spec:
      containers:
      - name: test-runner
        image: test-suite:latest
        command: ["/bin/sh"]
        args:
        - -c
        - |
          # Test database connectivity
          until pg_isready -h postgres-service -p 5432; do
            sleep 1
          done
          
          # Run integration tests
          npm run test:integration
          
          # API tests
          newman run api-tests.postman_collection.json
      restartPolicy: Never
```

#### 3. End-to-End Tests
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: e2e-tests
spec:
  template:
    spec:
      containers:
      - name: cypress
        image: cypress/included:latest
        command: ["cypress", "run"]
        env:
        - name: CYPRESS_baseUrl
          value: "http://frontend-service"
      restartPolicy: Never
```

#### 4. Performance Tests
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: performance-tests
spec:
  template:
    spec:
      containers:
      - name: k6
        image: loadimpact/k6:latest
        command: ["k6", "run", "/scripts/load-test.js"]
        env:
        - name: TARGET_URL
          value: "http://api-service"
```

---

## 5. Pipeline con Blue-Green Deployment

### Objetivo
Implementar despliegues sin downtime usando la estrategia Blue-Green.

### Configuración

#### 1. Script Blue-Green
```bash
#!/bin/bash
# blue-green-deploy.sh

CURRENT_COLOR=$(kubectl get service app-service -o jsonpath='{.spec.selector.color}')
NEW_COLOR=$([ "$CURRENT_COLOR" = "blue" ] && echo "green" || echo "blue")

echo "🔄 Desplegando versión $NEW_COLOR..."

# Desplegar nueva versión
envsubst < deployment-$NEW_COLOR.yaml | kubectl apply -f -

# Esperar a que esté listo
kubectl wait --for=condition=ready pod -l color=$NEW_COLOR --timeout=600s

# Ejecutar smoke tests
if run_smoke_tests $NEW_COLOR; then
    echo "✅ Smoke tests pasaron, cambiando tráfico..."
    
    # Cambiar service selector
    kubectl patch service app-service -p "{\"spec\":{\"selector\":{\"color\":\"$NEW_COLOR\"}}}"
    
    echo "🎯 Tráfico dirigido a $NEW_COLOR"
    
    # Opcional: eliminar versión anterior después de un tiempo
    sleep 300
    kubectl delete deployment app-$CURRENT_COLOR
else
    echo "❌ Smoke tests fallaron, manteniendo versión actual"
    kubectl delete deployment app-$NEW_COLOR
    exit 1
fi
```

#### 2. Service Configuration
```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: myapp
    color: blue  # Cambia dinámicamente
  ports:
  - port: 80
    targetPort: 3000
```

#### 3. Deployment Templates
```yaml
# deployment-blue.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      color: blue
  template:
    metadata:
      labels:
        app: myapp
        color: blue
    spec:
      containers:
      - name: app
        image: myapp:${BUILD_NUMBER}
```

---

## 6. Pipeline con Canary Deployment

### Objetivo
Implementar despliegues graduales con análisis automático de métricas.

### Configuración con Argo Rollouts

#### 1. Rollout Configuration
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: canary-rollout
spec:
  replicas: 10
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {duration: 30s}
      - setWeight: 20
      - pause: {duration: 30s}
      - setWeight: 50
      - pause: {duration: 60s}
      - setWeight: 100
      
      analysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: canary-service
          
  selector:
    matchLabels:
      app: canary-app
  template:
    metadata:
      labels:
        app: canary-app
    spec:
      containers:
      - name: app
        image: myapp:${BUILD_NUMBER}
```

#### 2. Analysis Template
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    interval: 30s
    count: 5
    successCondition: result[0] >= 0.95
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(http_requests_total{service="{{args.service-name}}",status!~"5.*"}[1m])) /
          sum(rate(http_requests_total{service="{{args.service-name}}"}[1m]))
```

#### 3. Pipeline Integration
```bash
# Desplegar con canary
kubectl apply -f canary-rollout.yaml

# Monitorear progreso
kubectl argo rollouts get rollout canary-rollout --watch

# Promover manualmente si es necesario
kubectl argo rollouts promote canary-rollout

# Abort si hay problemas
kubectl argo rollouts abort canary-rollout
```

---

## 7. Pipeline GitOps con ArgoCD

### Objetivo
Implementar GitOps donde Git es la única fuente de verdad para configuraciones.

### Configuración

#### 1. Estructura de Repositorio GitOps
```
gitops-config/
├── applications/
│   ├── dev/
│   │   └── myapp.yaml
│   ├── staging/
│   │   └── myapp.yaml
│   └── prod/
│       └── myapp.yaml
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/
    ├── staging/
    └── prod/
```

#### 2. ArgoCD Application
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/company/gitops-config
    targetRevision: HEAD
    path: applications/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

#### 3. Pipeline GitOps
```bash
#!/bin/bash
# gitops-pipeline.sh

# 1. Build y push imagen
./ci-cd-pipeline.sh build

# 2. Update imagen en repo GitOps
git clone https://github.com/company/gitops-config
cd gitops-config

# 3. Update image tag
sed -i "s|image: myapp:.*|image: myapp:${BUILD_NUMBER}|" applications/prod/myapp.yaml

# 4. Commit y push
git add .
git commit -m "Update myapp to ${BUILD_NUMBER}"
git push origin main

# 5. ArgoCD detectará el cambio y desplegará automáticamente
echo "✅ Imagen actualizada en GitOps repo. ArgoCD desplegará automáticamente."
```

---

## 8. Pipeline con Security Scanning

### Objetivo
Integrar análisis de seguridad en todas las fases del pipeline.

### Herramientas de Security

#### 1. Container Image Scanning
```bash
# Trivy scan
run_security_scan() {
    log_info "🔍 Ejecutando análisis de seguridad..."
    
    # Scan de vulnerabilidades
    trivy image --exit-code 1 --severity HIGH,CRITICAL $IMAGE_TAG
    
    # Scan de configuración
    trivy config --exit-code 1 kubernetes-config/
    
    # Scan de secrets
    truffleHog --regex --entropy=False .
}
```

#### 2. Static Code Analysis
```yaml
# SonarQube integration
apiVersion: batch/v1
kind: Job
metadata:
  name: code-analysis
spec:
  template:
    spec:
      containers:
      - name: sonarqube-scanner
        image: sonarqube:scanner-cli
        env:
        - name: SONAR_HOST_URL
          value: "http://sonarqube:9000"
        - name: SONAR_LOGIN
          valueFrom:
            secretKeyRef:
              name: sonar-secret
              key: token
      restartPolicy: Never
```

#### 3. Runtime Security
```yaml
# Falco rules for runtime monitoring
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-rules
data:
  app_rules.yaml: |
    - rule: Unauthorized Process in Container
      desc: Detect unauthorized process spawned in container
      condition: >
        spawned_process and container and
        not proc.name in (node, npm, sh, bash)
      output: >
        Unauthorized process in container
        (command=%proc.cmdline pid=%proc.pid container=%container.name)
      priority: WARNING
```

#### 4. Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-traffic
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 3000
```

---

## 9. Pipeline Multi-cluster

### Objetivo
Desplegar aplicaciones en múltiples clusters de Kubernetes para alta disponibilidad.

### Configuración

#### 1. Cluster Configuration
```bash
# Configurar múltiples contextos
kubectl config set-cluster cluster-us-east --server=https://us-east.k8s.company.com
kubectl config set-cluster cluster-eu-west --server=https://eu-west.k8s.company.com

kubectl config set-context us-east --cluster=cluster-us-east --user=deployer
kubectl config set-context eu-west --cluster=cluster-eu-west --user=deployer
```

#### 2. Multi-cluster Deploy Script
```bash
#!/bin/bash
# multi-cluster-deploy.sh

CLUSTERS=("us-east" "eu-west" "asia-pacific")

for cluster in "${CLUSTERS[@]}"; do
    echo "🌍 Desplegando en cluster: $cluster"
    
    # Cambiar contexto
    kubectl config use-context $cluster
    
    # Verificar conectividad
    if ! kubectl cluster-info &>/dev/null; then
        log_error "No se puede conectar a $cluster"
        continue
    fi
    
    # Desplegar aplicación
    CLUSTER_NAME=$cluster ./ci-cd-pipeline.sh deploy
    
    # Verificar health
    kubectl wait --for=condition=ready pod -l app=$APP_NAME --timeout=300s
    
    echo "✅ Desplegado exitosamente en $cluster"
done
```

#### 3. Cross-cluster Service Discovery
```yaml
# ServiceExport for multi-cluster
apiVersion: networking.x-k8s.io/v1alpha1
kind: ServiceExport
metadata:
  name: myapp-service
---
# ServiceImport for consuming from other clusters
apiVersion: networking.x-k8s.io/v1alpha1
kind: ServiceImport
metadata:
  name: myapp-service-remote
spec:
  type: ClusterSetIP
  ports:
  - port: 80
    protocol: TCP
```

---

## 10. Pipeline para Aplicaciones Serverless

### Objetivo
Desplegar funciones serverless usando Knative o OpenFaaS en Kubernetes.

### Configuración con Knative

#### 1. Knative Service
```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: serverless-app
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "0"
        autoscaling.knative.dev/maxScale: "100"
    spec:
      containers:
      - image: serverless-app:${BUILD_NUMBER}
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

#### 2. Serverless Pipeline
```bash
#!/bin/bash
# serverless-deploy.sh

# Build función serverless
docker build -t serverless-app:$BUILD_NUMBER .

# Deploy con Knative
kubectl apply -f knative-service.yaml

# Obtener URL de la función
FUNCTION_URL=$(kubectl get ksvc serverless-app -o jsonpath='{.status.url}')

# Test básico
curl -f $FUNCTION_URL/health

echo "✅ Función serverless desplegada en: $FUNCTION_URL"
```

#### 3. Event-driven Deployment
```yaml
# Knative Trigger para deployment automático
apiVersion: eventing.knative.dev/v1
kind: Trigger
metadata:
  name: deployment-trigger
spec:
  broker: default
  filter:
    attributes:
      type: dev.knative.source.github
      source: github.com/company/repo
  subscriber:
    ref:
      apiVersion: serving.knative.dev/v1
      kind: Service
      name: deployment-handler
```

---

## Comandos Útiles por Caso de Uso

### Monitoreo General
```bash
# Ver estado de todos los deployments
kubectl get deployments --all-namespaces

# Ver rollout status
kubectl rollout status deployment/myapp

# Ver logs de pipeline
kubectl logs -l job-name=ci-cd-pipeline

# Métricas de recursos
kubectl top pods --all-namespaces
```

### Debug de Pipeline
```bash
# Ver eventos recientes
kubectl get events --sort-by=.metadata.creationTimestamp

# Debug de pods fallidos
kubectl describe pod <pod-name>
kubectl logs <pod-name> --previous

# Test de conectividad
kubectl run debug --image=busybox -it --rm -- /bin/sh
```

### Rollback
```bash
# Ver historial
kubectl rollout history deployment/myapp

# Rollback a versión anterior
kubectl rollout undo deployment/myapp

# Rollback a versión específica
kubectl rollout undo deployment/myapp --to-revision=3
```

## Mejores Prácticas por Caso de Uso

1. **Seguridad**: Nunca hardcodear secrets, usar RBAC, escanear imágenes
2. **Observabilidad**: Logs estructurados, métricas, trazas distribuidas
3. **Testing**: Pirámide de testing, fail fast, smoke tests en producción
4. **Rollbacks**: Siempre tener estrategia de rollback, tested rollback paths
5. **Configuración**: Usar ConfigMaps/Secrets, separar config por entorno
6. **Resources**: Definir limits/requests, usar HPA cuando sea apropiado
7. **Dependencies**: Manejar dependencias entre servicios, health checks
8. **Documentation**: Documentar pipeline, runbooks para incidentes

Cada caso de uso puede combinarse según las necesidades específicas de tu organización y aplicaciones.
