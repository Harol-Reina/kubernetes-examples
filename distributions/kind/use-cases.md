# Casos de Uso para Kind (Kubernetes in Docker)

Este documento presenta casos de uso prácticos para utilizar Kind en diferentes escenarios de desarrollo, testing y CI/CD.

## Tabla de Contenidos

1. [Desarrollo Local Multi-Nodo](#desarrollo-local-multi-nodo)
2. [Testing de Aplicaciones](#testing-de-aplicaciones)
3. [CI/CD Pipeline Integration](#cicd-pipeline-integration)
4. [Network Testing](#network-testing)
5. [Storage Testing](#storage-testing)
6. [Multi-Cluster Testing](#multi-cluster-testing)
7. [Kubernetes Version Testing](#kubernetes-version-testing)
8. [Load Testing](#load-testing)
9. [Feature Flag Testing](#feature-flag-testing)
10. [Disaster Recovery Testing](#disaster-recovery-testing)

---

## Desarrollo Local Multi-Nodo

### Caso de Uso: Simulación de Cluster de Producción

**Escenario**: Un desarrollador necesita probar una aplicación que requiere comportamientos específicos de un cluster multi-nodo, como anti-afinidad de pods, distribución de carga, y tolerancia a fallos.

#### Configuración del Cluster

```yaml
# kind-multi-node-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: development-cluster
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "environment=development,tier=control-plane"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
  - containerPort: 443
    hostPort: 8443
    protocol: TCP
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "environment=development,tier=worker,zone=zone-a"
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "environment=development,tier=worker,zone=zone-b"
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "environment=development,tier=worker,zone=zone-c"
```

#### Aplicación con Anti-Afinidad

```yaml
# anti-affinity-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - web-app
            topologyKey: "kubernetes.io/hostname"
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: tier
                operator: In
                values:
                - worker
      containers:
      - name: web-app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
```

#### Script de Setup

```bash
#!/bin/bash
# setup-multi-node-development.sh

set -e

echo "🚀 Configurando cluster Kind multi-nodo para desarrollo..."

# Crear cluster
kind create cluster --config=kind-multi-node-config.yaml

# Esperar a que el cluster esté listo
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Instalar NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Esperar a que NGINX esté listo
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# Desplegar aplicación de prueba
kubectl apply -f anti-affinity-app.yaml

# Crear servicio e ingress
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-app-service
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-app-ingress
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-app-service
            port:
              number: 80
EOF

echo "✅ Cluster multi-nodo configurado"
echo "🌐 Aplicación disponible en: http://localhost:8080"
echo "🔍 Verificar distribución: kubectl get pods -o wide"
```

---

## Testing de Aplicaciones

### Caso de Uso: Testing Automatizado de Microservicios

**Escenario**: Un equipo de desarrollo necesita ejecutar tests de integración que requieren múltiples servicios desplegados en Kubernetes.

#### Test Suite Setup

```yaml
# test-environment.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: test-environment
---
# Database para tests
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-postgres
  namespace: test-environment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-postgres
  template:
    metadata:
      labels:
        app: test-postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_DB
          value: testdb
        - name: POSTGRES_USER
          value: testuser
        - name: POSTGRES_PASSWORD
          value: testpass
        ports:
        - containerPort: 5432
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: test-postgres
  namespace: test-environment
spec:
  selector:
    app: test-postgres
  ports:
  - port: 5432
    targetPort: 5432
---
# Redis para cache
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-redis
  namespace: test-environment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-redis
  template:
    metadata:
      labels:
        app: test-redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        resources:
          requests:
            memory: "128Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: test-redis
  namespace: test-environment
spec:
  selector:
    app: test-redis
  ports:
  - port: 6379
    targetPort: 6379
```

#### Test Runner Job

```yaml
# integration-test-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: integration-tests
  namespace: test-environment
spec:
  template:
    spec:
      containers:
      - name: test-runner
        image: node:18-alpine
        command:
        - /bin/sh
        - -c
        - |
          npm install
          npm run test:integration
        env:
        - name: DATABASE_URL
          value: "postgresql://testuser:testpass@test-postgres:5432/testdb"
        - name: REDIS_URL
          value: "redis://test-redis:6379"
        - name: TEST_ENVIRONMENT
          value: "kubernetes"
        volumeMounts:
        - name: test-code
          mountPath: /app
        workingDir: /app
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "500m"
      volumes:
      - name: test-code
        configMap:
          name: test-code
      restartPolicy: Never
  backoffLimit: 3
```

#### Automated Test Script

```bash
#!/bin/bash
# run-integration-tests.sh

set -e

TEST_NAMESPACE="test-environment"
CLUSTER_NAME="testing-cluster"

echo "🧪 Ejecutando tests de integración en Kind..."

# Función para limpiar recursos
cleanup() {
    echo "🧹 Limpiando recursos de test..."
    kubectl delete namespace $TEST_NAMESPACE --ignore-not-found=true
    kind delete cluster --name $CLUSTER_NAME 2>/dev/null || true
}

# Configurar trap para limpiar en caso de error
trap cleanup EXIT

# Crear cluster temporal para tests
cat <<EOF > kind-test-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $CLUSTER_NAME
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

kind create cluster --config=kind-test-config.yaml

# Esperar a que el cluster esté listo
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Crear namespace de test
kubectl create namespace $TEST_NAMESPACE

# Desplegar infraestructura de test
kubectl apply -f test-environment.yaml

# Esperar a que los servicios estén listos
kubectl wait --for=condition=ready pod -l app=test-postgres -n $TEST_NAMESPACE --timeout=300s
kubectl wait --for=condition=ready pod -l app=test-redis -n $TEST_NAMESPACE --timeout=300s

# Crear ConfigMap con código de test
kubectl create configmap test-code \
  --from-file=./tests/ \
  --namespace=$TEST_NAMESPACE

# Ejecutar tests
kubectl apply -f integration-test-job.yaml

# Esperar a que los tests terminen
kubectl wait --for=condition=complete job/integration-tests -n $TEST_NAMESPACE --timeout=600s

# Obtener resultados
echo "📊 Resultados de los tests:"
kubectl logs job/integration-tests -n $TEST_NAMESPACE

# Verificar si los tests pasaron
if kubectl get job integration-tests -n $TEST_NAMESPACE -o jsonpath='{.status.succeeded}' | grep -q "1"; then
    echo "✅ Todos los tests pasaron exitosamente"
    exit 0
else
    echo "❌ Algunos tests fallaron"
    exit 1
fi
```

---

## CI/CD Pipeline Integration

### Caso de Uso: GitHub Actions con Kind

**Escenario**: Configurar un pipeline de CI/CD que utilice Kind para ejecutar tests en cada commit.

#### GitHub Actions Workflow

```yaml
# .github/workflows/ci.yml
name: CI Pipeline with Kind

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3
      
    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
        
    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=sha,prefix={{branch}}-
          
    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
        
    - name: Set up Kind cluster
      uses: helm/kind-action@v1.8.0
      with:
        cluster_name: ci-cluster
        config: .github/kind-ci-config.yaml
        
    - name: Install NGINX Ingress
      run: |
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
        kubectl wait --namespace ingress-nginx \
          --for=condition=ready pod \
          --selector=app.kubernetes.io/component=controller \
          --timeout=300s
          
    - name: Load image to Kind
      run: |
        kind load docker-image ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} --name ci-cluster
        
    - name: Deploy to Kind cluster
      run: |
        envsubst < k8s/deployment.yaml | kubectl apply -f -
        kubectl wait --for=condition=ready pod -l app=myapp --timeout=300s
      env:
        IMAGE_TAG: ${{ github.sha }}
        
    - name: Run integration tests
      run: |
        kubectl apply -f k8s/test-job.yaml
        kubectl wait --for=condition=complete job/integration-tests --timeout=600s
        
    - name: Get test results
      run: |
        kubectl logs job/integration-tests
        
    - name: Run security scan
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
        format: 'sarif'
        output: 'trivy-results.sarif'
        
    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'
```

#### Kind Configuration for CI

```yaml
# .github/kind-ci-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ci-cluster
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "environment=ci"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
  - containerPort: 443
    hostPort: 8443
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "environment=ci,tier=worker"
```

---

## Network Testing

### Caso de Uso: Testing de Network Policies

**Escenario**: Validar que las network policies funcionen correctamente antes de desplegar en producción.

#### Network Policy Test Setup

```yaml
# network-policy-test.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: frontend
  labels:
    tier: frontend
---
apiVersion: v1
kind: Namespace
metadata:
  name: backend
  labels:
    tier: backend
---
apiVersion: v1
kind: Namespace
metadata:
  name: database
  labels:
    tier: database
---
# Frontend app
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-app
  namespace: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
---
# Backend app
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-app
  namespace: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        tier: backend
    spec:
      containers:
      - name: backend
        image: httpd:alpine
        ports:
        - containerPort: 80
---
# Database
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
        tier: database
    spec:
      containers:
      - name: database
        image: postgres:15-alpine
        env:
        - name: POSTGRES_PASSWORD
          value: testpass
        ports:
        - containerPort: 5432
---
# Network Policies
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-netpol
  namespace: frontend
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 80
  - to: []  # Allow DNS
    ports:
    - protocol: UDP
      port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-netpol
  namespace: backend
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          tier: database
    ports:
    - protocol: TCP
      port: 5432
  - to: []  # Allow DNS
    ports:
    - protocol: UDP
      port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-netpol
  namespace: database
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 5432
```

#### Network Testing Script

```bash
#!/bin/bash
# test-network-policies.sh

set -e

echo "🔒 Testing Network Policies en Kind..."

# Crear cluster con Calico CNI para Network Policies
cat <<EOF > kind-netpol-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: netpol-test
networking:
  disableDefaultCNI: true
  podSubnet: "192.168.0.0/16"
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

kind create cluster --config=kind-netpol-config.yaml

# Instalar Calico
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/tigera-operator.yaml

cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: 192.168.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
EOF

# Esperar a que Calico esté listo
kubectl wait --for=condition=Ready pods -l k8s-app=calico-node -n calico-system --timeout=300s

# Desplegar aplicaciones y policies
kubectl apply -f network-policy-test.yaml

# Esperar a que los pods estén listos
kubectl wait --for=condition=ready pod -l app=frontend -n frontend --timeout=300s
kubectl wait --for=condition=ready pod -l app=backend -n backend --timeout=300s
kubectl wait --for=condition=ready pod -l app=database -n database --timeout=300s

echo "🧪 Ejecutando tests de conectividad..."

# Test 1: Frontend debe poder conectar a Backend
echo "Test 1: Frontend -> Backend"
FRONTEND_POD=$(kubectl get pod -l app=frontend -n frontend -o jsonpath='{.items[0].metadata.name}')
BACKEND_IP=$(kubectl get pod -l app=backend -n backend -o jsonpath='{.items[0].status.podIP}')

if kubectl exec -n frontend $FRONTEND_POD -- wget -qO- --timeout=5 http://$BACKEND_IP >/dev/null 2>&1; then
    echo "✅ Frontend puede conectar a Backend"
else
    echo "❌ Frontend NO puede conectar a Backend"
fi

# Test 2: Frontend NO debe poder conectar directamente a Database
echo "Test 2: Frontend -> Database (debe fallar)"
DATABASE_IP=$(kubectl get pod -l app=database -n database -o jsonpath='{.items[0].status.podIP}')

if kubectl exec -n frontend $FRONTEND_POD -- timeout 5 bash -c "echo > /dev/tcp/$DATABASE_IP/5432" >/dev/null 2>&1; then
    echo "❌ Frontend puede conectar a Database (POLÍTICA FALLÓ)"
else
    echo "✅ Frontend NO puede conectar a Database (POLÍTICA CORRECTA)"
fi

# Test 3: Backend debe poder conectar a Database
echo "Test 3: Backend -> Database"
BACKEND_POD=$(kubectl get pod -l app=backend -n backend -o jsonpath='{.items[0].metadata.name}')

if kubectl exec -n backend $BACKEND_POD -- timeout 5 bash -c "echo > /dev/tcp/$DATABASE_IP/5432" >/dev/null 2>&1; then
    echo "✅ Backend puede conectar a Database"
else
    echo "❌ Backend NO puede conectar a Database"
fi

echo "🏁 Tests de Network Policy completados"
```

---

## Storage Testing

### Caso de Uso: Testing de Persistent Volumes

**Escenario**: Validar el comportamiento de almacenamiento persistente y backup/restore.

#### Storage Test Setup

```yaml
# storage-test.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: default
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: data-app
spec:
  serviceName: data-app
  replicas: 2
  selector:
    matchLabels:
      app: data-app
  template:
    metadata:
      labels:
        app: data-app
    spec:
      containers:
      - name: app
        image: alpine:latest
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            echo "$(date): Writing data..." >> /data/log.txt
            sleep 30
          done
        volumeMounts:
        - name: data-volume
          mountPath: /data
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
  volumeClaimTemplates:
  - metadata:
      name: data-volume
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: standard
      resources:
        requests:
          storage: 500Mi
```

#### Storage Test Script

```bash
#!/bin/bash
# test-storage.sh

set -e

echo "💾 Testing Persistent Storage en Kind..."

# Crear cluster con configuración de storage
cat <<EOF > kind-storage-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: storage-test
nodes:
- role: control-plane
  extraMounts:
  - hostPath: /tmp/kind-storage
    containerPath: /var/local-path-provisioner
- role: worker
  extraMounts:
  - hostPath: /tmp/kind-storage
    containerPath: /var/local-path-provisioner
EOF

# Crear directorio de storage en host
mkdir -p /tmp/kind-storage

kind create cluster --config=kind-storage-config.yaml

# Esperar a que el cluster esté listo
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Desplegar StatefulSet con storage
kubectl apply -f storage-test.yaml

# Esperar a que los pods estén listos
kubectl wait --for=condition=ready pod -l app=data-app --timeout=300s

echo "📝 Escribiendo datos de prueba..."

# Escribir datos únicos en cada pod
kubectl exec data-app-0 -- sh -c 'echo "Data from pod-0: $(date)" >> /data/test-file.txt'
kubectl exec data-app-1 -- sh -c 'echo "Data from pod-1: $(date)" >> /data/test-file.txt'

# Verificar que los datos se escribieron
echo "📖 Datos en pod-0:"
kubectl exec data-app-0 -- cat /data/test-file.txt

echo "📖 Datos en pod-1:"
kubectl exec data-app-1 -- cat /data/test-file.txt

echo "🔄 Testing persistencia después de restart..."

# Eliminar pods para probar persistencia
kubectl delete pod data-app-0 data-app-1

# Esperar a que se recreen
kubectl wait --for=condition=ready pod -l app=data-app --timeout=300s

# Verificar que los datos persisten
echo "📖 Datos después del restart en pod-0:"
kubectl exec data-app-0 -- cat /data/test-file.txt

echo "📖 Datos después del restart en pod-1:"
kubectl exec data-app-1 -- cat /data/test-file.txt

# Probar expansión de volumen
echo "📈 Testing expansión de volumen..."
kubectl patch pvc data-volume-data-app-0 -p '{"spec":{"resources":{"requests":{"storage":"1Gi"}}}}'

# Verificar que el PVC se expandió
kubectl get pvc data-volume-data-app-0

echo "✅ Tests de storage completados"
```

Este documento continúa con más casos de uso prácticos para Kind, cubriendo diferentes aspectos del desarrollo y testing con Kubernetes.
