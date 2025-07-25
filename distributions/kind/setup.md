# Configuración y Setup de Kind (Kubernetes in Docker)

Kind es una herramienta para ejecutar clusters locales de Kubernetes usando nodos de contenedores Docker. Es ideal para testing, desarrollo local y CI/CD.

## Tabla de Contenidos

1. [¿Qué es Kind?](#qué-es-kind)
2. [Instalación](#instalación)
3. [Configuración Básica](#configuración-básica)
4. [Configuraciones Avanzadas](#configuraciones-avanzadas)
5. [Networking](#networking)
6. [Storage](#storage)
7. [Multi-node Clusters](#multi-node-clusters)
8. [Integración con CI/CD](#integración-con-cicd)
9. [Troubleshooting](#troubleshooting)
10. [Mejores Prácticas](#mejores-prácticas)

---

## ¿Qué es Kind?

Kind (Kubernetes in Docker) es una herramienta que permite ejecutar clusters de Kubernetes locales usando contenedores Docker como nodos. Fue desarrollado principalmente para testing de Kubernetes, pero es excelente para desarrollo local.

### Ventajas de Kind

- **Rápido**: Clusters ligeros y rápidos de crear/destruir
- **Aislamiento**: Cada cluster está completamente aislado
- **Versiones**: Soporte para múltiples versiones de Kubernetes
- **CI/CD**: Ideal para pipelines de integración continua
- **Multi-node**: Soporte para clusters multi-nodo
- **Portable**: Funciona en Linux, macOS y Windows

### Casos de Uso

- Testing de aplicaciones Kubernetes
- Desarrollo local de aplicaciones cloud-native
- CI/CD pipelines
- Demos y tutorials
- Testing de operadores y controllers

---

## Instalación

### 1. Prerequisitos

```bash
# Docker debe estar instalado y corriendo
docker --version
# Docker version 20.10.0+

# Go (opcional, para compilar desde fuente)
go version
# go version go1.19+
```

### 2. Instalación en Linux

```bash
# Método 1: Descarga directa
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Método 2: Go install
go install sigs.k8s.io/kind@v0.20.0

# Método 3: Package manager
# Debian/Ubuntu
sudo apt-get update && sudo apt-get install -y kind

# Arch Linux
yay -S kind-bin
```

### 3. Instalación en macOS

```bash
# Homebrew
brew install kind

# MacPorts
sudo port install kind

# Manual
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### 4. Instalación en Windows

```powershell
# Chocolatey
choco install kind

# Manual
curl.exe -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64
Move-Item .\kind-windows-amd64.exe c:\some-dir-in-your-PATH\kind.exe
```

### 5. Verificar Instalación

```bash
kind version
# kind v0.20.0 go1.20.4 linux/amd64

# También instalar kubectl si no está presente
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

---

## Configuración Básica

### 1. Crear tu Primer Cluster

```bash
# Crear cluster con configuración por defecto
kind create cluster

# Crear cluster con nombre específico
kind create cluster --name my-cluster

# Especificar versión de Kubernetes
kind create cluster --image kindest/node:v1.28.0

# Ver clusters disponibles
kind get clusters

# Obtener kubeconfig
kind get kubeconfig --name my-cluster

# Verificar cluster
kubectl cluster-info --context kind-my-cluster
```

### 2. Configuración Básica con Archivo

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: development
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
```

```bash
# Crear cluster con configuración
kind create cluster --config kind-config.yaml

# Eliminar cluster
kind delete cluster --name development
```

### 3. Script de Setup Básico

```bash
#!/bin/bash
# setup-kind.sh

set -e

CLUSTER_NAME="development"
K8S_VERSION="v1.28.0"

echo "🚀 Configurando cluster Kind..."

# Verificar que Docker esté corriendo
if ! docker info &>/dev/null; then
    echo "❌ Docker no está corriendo"
    exit 1
fi

# Crear cluster
echo "📦 Creando cluster $CLUSTER_NAME..."
kind create cluster \
    --name $CLUSTER_NAME \
    --image kindest/node:$K8S_VERSION \
    --config kind-config.yaml

# Configurar kubectl context
kubectl cluster-info --context kind-$CLUSTER_NAME

# Instalar ingress controller
echo "🌐 Instalando NGINX Ingress..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Esperar a que esté listo
echo "⏳ Esperando a que Ingress esté listo..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

echo "✅ Cluster Kind configurado exitosamente!"
echo "🔧 Contexto actual: $(kubectl config current-context)"
```

---

## Configuraciones Avanzadas

### 1. Cluster Multi-Master

```yaml
# ha-cluster-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ha-cluster
nodes:
# Control plane nodes
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
  - containerPort: 443
    hostPort: 443
- role: control-plane
- role: control-plane
# Worker nodes
- role: worker
  labels:
    tier: frontend
- role: worker
  labels:
    tier: backend
- role: worker
  labels:
    tier: database
```

### 2. Configuración con Registry Local

```yaml
# registry-cluster-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: registry-cluster
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5001"]
    endpoint = ["http://kind-registry:5001"]
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
  - containerPort: 443
    hostPort: 443
- role: worker
- role: worker
```

```bash
#!/bin/bash
# setup-with-registry.sh

# Crear registry local si no existe
if [ "$(docker inspect -f '{{.State.Running}}' kind-registry 2>/dev/null || true)" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:5001:5000" --name kind-registry \
    registry:2
fi

# Crear cluster con registry
kind create cluster --config registry-cluster-config.yaml

# Conectar registry al cluster
docker network connect "kind" "kind-registry" || true

# Documentar el registry local
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:5001"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

echo "✅ Registry local disponible en localhost:5001"
```

### 3. Configuración para Development

```yaml
# dev-cluster-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: dev-cluster
nodes:
- role: control-plane
  image: kindest/node:v1.28.0
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
        system-reserved: "cpu=100m,memory=100Mi"
        kube-reserved: "cpu=100m,memory=100Mi"
        eviction-hard: "memory.available<200Mi"
  extraMounts:
  - hostPath: /tmp/kind-data
    containerPath: /data
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
  - containerPort: 443
    hostPort: 8443
  - containerPort: 30000
    hostPort: 30000
  - containerPort: 30001
    hostPort: 30001
- role: worker
  image: kindest/node:v1.28.0
  extraMounts:
  - hostPath: /tmp/kind-data
    containerPath: /data
- role: worker
  image: kindest/node:v1.28.0
  extraMounts:
  - hostPath: /tmp/kind-data
    containerPath: /data
```

---

## Networking

### 1. Port Mapping y Ingress

```yaml
# ingress-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ingress-cluster
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 8080
    hostPort: 8080
    protocol: TCP
```

### 2. Setup de Ingress NGINX

```bash
#!/bin/bash
# setup-ingress.sh

echo "🌐 Configurando Ingress NGINX para Kind..."

# Aplicar manifiestos de Ingress NGINX específicos para Kind
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Esperar a que el controlador esté listo
echo "⏳ Esperando a que Ingress Controller esté listo..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# Verificar que está funcionando
echo "🔍 Verificando Ingress Controller..."
kubectl get pods -n ingress-nginx

# Test básico
echo "🧪 Testing Ingress Controller..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
      - name: hello-world
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: hello-world
spec:
  selector:
    app: hello-world
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world
spec:
  rules:
  - host: hello.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-world
            port:
              number: 80
EOF

echo "✅ Ingress configurado. Test en: http://hello.local (agregar a /etc/hosts)"
echo "127.0.0.1 hello.local" | sudo tee -a /etc/hosts
```

### 3. LoadBalancer con MetalLB

```bash
#!/bin/bash
# setup-metallb.sh

echo "⚖️ Configurando MetalLB LoadBalancer..."

# Obtener subnet de Docker Kind
KIND_SUBNET=$(docker network inspect -f '{{.IPAM.Config}}' kind | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+' | head -1)
KIND_NET=$(echo $KIND_SUBNET | cut -d'/' -f1 | cut -d'.' -f1-3)

# Instalar MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# Esperar a que esté listo
kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=app=metallb \
                --timeout=90s

# Configurar pool de IPs
kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: example
  namespace: metallb-system
spec:
  addresses:
  - ${KIND_NET}.200-${KIND_NET}.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF

echo "✅ MetalLB configurado con pool: ${KIND_NET}.200-${KIND_NET}.250"
```

---

## Storage

### 1. Local Path Provisioner

```bash
#!/bin/bash
# setup-storage.sh

echo "💾 Configurando Local Path Provisioner..."

# El Local Path Provisioner ya viene instalado por defecto en Kind
kubectl get storageclass

# Crear un ejemplo de PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: standard
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-storage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-storage
  template:
    metadata:
      labels:
        app: test-storage
    spec:
      containers:
      - name: test
        image: nginx
        volumeMounts:
        - name: storage
          mountPath: /data
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: test-pvc
EOF

echo "✅ Storage configurado. PVC creado y montado en deployment."
```

### 2. Configuración de CSI

```yaml
# csi-driver-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-path-config
  namespace: local-path-storage
data:
  config.json: |-
    {
      "nodePathMap":[
        {
          "node":"DEFAULT_PATH_FOR_NON_LISTED_NODES",
          "paths":["/opt/local-path-provisioner"]
        }
      ]
    }
  setup: |-
    #!/bin/sh
    while getopts "m:s:p:" opt
    do
        case $opt in
            p)
            absolutePath=$OPTARG
            ;;
            s)
            sizeInBytes=$OPTARG
            ;;
            m)
            volMode=$OPTARG
            ;;
        esac
    done

    mkdir -m 0777 -p ${absolutePath}
  teardown: |-
    #!/bin/sh
    while getopts "m:s:p:" opt
    do
        case $opt in
            p)
            absolutePath=$OPTARG
            ;;
            s)
            sizeInBytes=$OPTARG
            ;;
            m)
            volMode=$OPTARG
            ;;
        esac
    done

    rm -rf ${absolutePath}
```

---

## Multi-node Clusters

### 1. Configuración de Cluster Grande

```yaml
# large-cluster-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: large-cluster
nodes:
# Control plane nodes (HA)
- role: control-plane
  image: kindest/node:v1.28.0
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
  - containerPort: 443
    hostPort: 443
- role: control-plane
  image: kindest/node:v1.28.0
- role: control-plane
  image: kindest/node:v1.28.0

# Worker nodes con labels específicos
- role: worker
  image: kindest/node:v1.28.0
  labels:
    node-type: compute
    tier: frontend
- role: worker
  image: kindest/node:v1.28.0
  labels:
    node-type: compute
    tier: frontend
- role: worker
  image: kindest/node:v1.28.0
  labels:
    node-type: storage
    tier: backend
- role: worker
  image: kindest/node:v1.28.0
  labels:
    node-type: storage
    tier: backend
- role: worker
  image: kindest/node:v1.28.0
  labels:
    node-type: database
    tier: data
```

### 2. Testing de Node Affinity

```yaml
# node-affinity-test.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: tier
                operator: In
                values:
                - frontend
      containers:
      - name: app
        image: nginx
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: tier
                operator: In
                values:
                - data
      containers:
      - name: db
        image: postgres:15-alpine
        env:
        - name: POSTGRES_PASSWORD
          value: "testpass"
```

---

## Integración con CI/CD

### 1. GitHub Actions

```yaml
# .github/workflows/kind-test.yml
name: Kind E2E Tests
on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  kind-test:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Kind
      uses: helm/kind-action@v1.8.0
      with:
        version: v0.20.0
        kubectl_version: v1.28.0
        cluster_name: test-cluster
        config: .github/kind-config.yaml

    - name: Load Docker Images
      run: |
        docker build -t myapp:test .
        kind load docker-image myapp:test --name test-cluster

    - name: Deploy Application
      run: |
        kubectl apply -f k8s/
        kubectl wait --for=condition=ready pod -l app=myapp --timeout=300s

    - name: Run Tests
      run: |
        kubectl get pods
        # Ejecutar tests E2E aquí
        
    - name: Cleanup
      if: always()
      run: |
        kind delete cluster --name test-cluster
```

### 2. Jenkins Pipeline

```groovy
// Jenkinsfile
pipeline {
    agent any
    
    environment {
        KUBECONFIG = "${WORKSPACE}/.kubeconfig"
    }
    
    stages {
        stage('Setup Kind Cluster') {
            steps {
                script {
                    sh '''
                        # Crear cluster Kind
                        kind create cluster --name jenkins-test --kubeconfig ${KUBECONFIG}
                        
                        # Verificar cluster
                        kubectl cluster-info --kubeconfig ${KUBECONFIG}
                    '''
                }
            }
        }
        
        stage('Build and Load Images') {
            steps {
                script {
                    sh '''
                        # Build imagen
                        docker build -t myapp:${BUILD_NUMBER} .
                        
                        # Cargar imagen en Kind
                        kind load docker-image myapp:${BUILD_NUMBER} --name jenkins-test
                    '''
                }
            }
        }
        
        stage('Deploy to Kind') {
            steps {
                script {
                    sh '''
                        # Aplicar manifiestos
                        envsubst < k8s/deployment.yaml | kubectl apply -f - --kubeconfig ${KUBECONFIG}
                        
                        # Esperar deployment
                        kubectl wait --for=condition=ready pod -l app=myapp --timeout=300s --kubeconfig ${KUBECONFIG}
                    '''
                }
            }
        }
        
        stage('Run Tests') {
            steps {
                script {
                    sh '''
                        # Ejecutar tests de integración
                        kubectl apply -f k8s/test-job.yaml --kubeconfig ${KUBECONFIG}
                        kubectl wait --for=condition=complete job/integration-test --timeout=600s --kubeconfig ${KUBECONFIG}
                    '''
                }
            }
        }
    }
    
    post {
        always {
            script {
                sh '''
                    # Obtener logs para debugging
                    kubectl logs -l app=myapp --kubeconfig ${KUBECONFIG} || true
                    
                    # Limpiar cluster
                    kind delete cluster --name jenkins-test || true
                '''
            }
        }
    }
}
```

### 3. Script de CI/CD Genérico

```bash
#!/bin/bash
# kind-ci.sh

set -e

CLUSTER_NAME="ci-test-$(date +%s)"
IMAGE_TAG="test-$(git rev-parse --short HEAD)"

echo "🚀 Iniciando CI/CD con Kind..."

# Trap para cleanup
cleanup() {
    echo "🧹 Limpiando recursos..."
    kind delete cluster --name $CLUSTER_NAME || true
}
trap cleanup EXIT

# Crear cluster
echo "📦 Creando cluster Kind..."
kind create cluster --name $CLUSTER_NAME --config ci-kind-config.yaml

# Build y load imagen
echo "🏗️ Construyendo y cargando imagen..."
docker build -t myapp:$IMAGE_TAG .
kind load docker-image myapp:$IMAGE_TAG --name $CLUSTER_NAME

# Deploy aplicación
echo "🚀 Desplegando aplicación..."
export IMAGE_TAG
envsubst < k8s/deployment-template.yaml | kubectl apply -f -

# Esperar a que esté listo
echo "⏳ Esperando deployment..."
kubectl wait --for=condition=ready pod -l app=myapp --timeout=300s

# Ejecutar tests
echo "🧪 Ejecutando tests..."
kubectl apply -f k8s/test-suite.yaml
kubectl wait --for=condition=complete job/test-suite --timeout=600s

# Verificar resultado
if kubectl get job test-suite -o jsonpath='{.status.succeeded}' | grep -q "1"; then
    echo "✅ Tests pasaron exitosamente!"
    exit 0
else
    echo "❌ Tests fallaron!"
    kubectl logs job/test-suite
    exit 1
fi
```

---

## Troubleshooting

### 1. Problemas Comunes

#### Cluster no inicia
```bash
# Verificar logs de Docker
docker logs kind-control-plane

# Verificar recursos del sistema
docker system df

# Limpiar recursos
docker system prune -f
kind delete clusters --all
```

#### Problemas de Red
```bash
# Verificar conectividad
kubectl get nodes -o wide

# Verificar CNI
kubectl get pods -n kube-system

# Reset de red
kind delete cluster --name problematic-cluster
docker network prune -f
```

#### Problemas de Storage
```bash
# Verificar PVs y PVCs
kubectl get pv,pvc --all-namespaces

# Verificar Local Path Provisioner
kubectl get pods -n local-path-storage

# Limpiar storage
docker exec -it kind-control-plane rm -rf /opt/local-path-provisioner/*
```

### 2. Debugging Avanzado

```bash
#!/bin/bash
# debug-kind.sh

CLUSTER_NAME=${1:-kind}

echo "🔍 Debugging cluster Kind: $CLUSTER_NAME"

# Información básica
echo "📊 Información del cluster:"
kubectl cluster-info --context kind-$CLUSTER_NAME

# Nodos
echo "🖥️ Nodos:"
kubectl get nodes -o wide

# Pods del sistema
echo "⚙️ Pods del sistema:"
kubectl get pods -n kube-system

# Recursos
echo "📈 Uso de recursos:"
kubectl top nodes || echo "Metrics server no disponible"

# Logs de nodos
echo "📋 Logs de nodos Kind:"
for node in $(docker ps --filter "name=kind-$CLUSTER_NAME" --format "{{.Names}}"); do
    echo "--- Logs de $node ---"
    docker logs $node --tail=20
done

# Verificar networking
echo "🌐 Verificando networking:"
kubectl run debug-pod --image=nicolaka/netshoot -it --rm --restart=Never -- /bin/bash -c "
    echo 'DNS Resolution:'
    nslookup kubernetes.default.svc.cluster.local
    echo 'Network connectivity:'
    ping -c 3 google.com || true
"

echo "✅ Debug completado"
```

---

## Mejores Prácticas

### 1. Gestión de Clusters

```bash
#!/bin/bash
# kind-manager.sh

# Función para crear cluster de desarrollo
create_dev_cluster() {
    local name=${1:-dev}
    
    cat > /tmp/kind-$name.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $name
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
  - containerPort: 443
    hostPort: 8443
- role: worker
- role: worker
EOF

    kind create cluster --config /tmp/kind-$name.yaml
    rm /tmp/kind-$name.yaml
}

# Función para crear cluster de testing
create_test_cluster() {
    local name=${1:-test}
    
    kind create cluster --name $name --image kindest/node:v1.28.0
    
    # Setup básico para testing
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s
}

# Función para limpiar todos los clusters
cleanup_all() {
    echo "🧹 Limpiando todos los clusters Kind..."
    kind get clusters | xargs -r kind delete cluster --name
    docker system prune -f
}

# Función para listar clusters con info
list_clusters() {
    echo "📋 Clusters Kind disponibles:"
    for cluster in $(kind get clusters); do
        echo "- $cluster (contexto: kind-$cluster)"
        kubectl config get-contexts kind-$cluster &>/dev/null && echo "  ✅ Contexto disponible" || echo "  ❌ Contexto no disponible"
    done
}

# Menú interactivo
case "${1:-menu}" in
    "dev")
        create_dev_cluster $2
        ;;
    "test")
        create_test_cluster $2
        ;;
    "list")
        list_clusters
        ;;
    "cleanup")
        cleanup_all
        ;;
    "menu")
        echo "Kind Cluster Manager"
        echo "Uso: $0 [dev|test|list|cleanup] [nombre]"
        echo ""
        echo "Comandos:"
        echo "  dev [nombre]    - Crear cluster de desarrollo"
        echo "  test [nombre]   - Crear cluster de testing"
        echo "  list           - Listar clusters"
        echo "  cleanup        - Limpiar todos los clusters"
        ;;
    *)
        echo "Comando desconocido: $1"
        $0 menu
        exit 1
        ;;
esac
```

### 2. Configuración de Recursos

```yaml
# production-like-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: production-like
nodes:
- role: control-plane
  image: kindest/node:v1.28.0
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
        system-reserved: "cpu=100m,memory=100Mi"
        kube-reserved: "cpu=100m,memory=100Mi"
        eviction-hard: "memory.available<200Mi"
        max-pods: "110"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
  - containerPort: 443
    hostPort: 443
- role: worker
  image: kindest/node:v1.28.0
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        system-reserved: "cpu=100m,memory=100Mi"
        kube-reserved: "cpu=100m,memory=100Mi"
        eviction-hard: "memory.available<200Mi"
        max-pods: "110"
- role: worker
  image: kindest/node:v1.28.0
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        system-reserved: "cpu=100m,memory=100Mi"
        kube-reserved: "cpu=100m,memory=100Mi"
        eviction-hard: "memory.available<200Mi"
        max-pods: "110"
```

### 3. Template de Testing

```bash
#!/bin/bash
# kind-test-template.sh

set -e

# Configuración
CLUSTER_NAME="test-$(date +%s)"
APP_NAME="test-app"
IMAGE_TAG="test-$(git rev-parse --short HEAD)"

# Función de cleanup
cleanup() {
    echo "🧹 Cleanup..."
    kubectl delete deployment,service,ingress -l app=$APP_NAME --ignore-not-found=true
    kind delete cluster --name $CLUSTER_NAME
}

# Trap para cleanup automático
trap cleanup EXIT

echo "🚀 Iniciando test con Kind..."

# Crear cluster temporal
kind create cluster --name $CLUSTER_NAME

# Build imagen
docker build -t $APP_NAME:$IMAGE_TAG .
kind load docker-image $APP_NAME:$IMAGE_TAG --name $CLUSTER_NAME

# Deploy aplicación
kubectl create deployment $APP_NAME --image=$APP_NAME:$IMAGE_TAG
kubectl expose deployment $APP_NAME --port=80 --target-port=8080

# Esperar a que esté listo
kubectl wait --for=condition=ready pod -l app=$APP_NAME --timeout=300s

# Port forward para testing
kubectl port-forward service/$APP_NAME 8080:80 &
PF_PID=$!

# Esperar a que port-forward esté listo
sleep 5

# Ejecutar tests
echo "🧪 Ejecutando tests..."
curl -f http://localhost:8080/health || (echo "❌ Health check falló"; exit 1)

# Test adicional
if [ -f "test-suite.sh" ]; then
    ./test-suite.sh
fi

# Cleanup del port-forward
kill $PF_PID 2>/dev/null || true

echo "✅ Tests completados exitosamente!"
```

Con Kind, tienes una herramienta poderosa y ligera para desarrollo y testing de aplicaciones Kubernetes. Es especialmente útil para CI/CD pipelines y desarrollo local donde necesitas clusters rápidos y efímeros.

**Próximos pasos recomendados:**
1. Explorar integración con herramientas de desarrollo como Skaffold
2. Implementar testing automatizado con Kind en CI/CD
3. Experimentar con configuraciones avanzadas como multi-cluster
4. Integrar con herramientas de observabilidad para testing
