# Configuraciones Específicas de Kind

Esta carpeta contiene configuraciones y ejemplos que aprovechan características específicas de Kind (Kubernetes in Docker) que lo diferencian de otras distribuciones.

## 🎯 Contenido Específico de Kind

### 1. Configuraciones de Cluster Multi-Nodo

#### Cluster con Workers Dedicados
```yaml
# kind-multi-worker-config.yaml
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

#### Cluster HA (Multiple Control Planes)
```yaml
# kind-ha-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ha-cluster
nodes:
- role: control-plane
- role: control-plane
- role: control-plane
- role: worker
- role: worker
- role: worker
networking:
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
```

### 2. Configuración de Port Mapping

#### Aplicación con Port Mapping Específico
```yaml
# kind-port-mapping.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: port-mapping-cluster
nodes:
- role: control-plane
  extraPortMappings:
  # Web application
  - containerPort: 30001
    hostPort: 3000
    protocol: TCP
  # Database
  - containerPort: 30002
    hostPort: 5432
    protocol: TCP
  # Monitoring
  - containerPort: 30003
    hostPort: 9090
    protocol: TCP
  # Dashboard
  - containerPort: 30004
    hostPort: 8080
    protocol: TCP
```

```yaml
# nodeport-service-kind.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app-nodeport
spec:
  type: NodePort
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30001  # Debe coincidir con extraPortMappings
```

### 3. Configuración de Registry Local

#### Registry Docker Local para Kind
```bash
#!/bin/bash
# setup-local-registry.sh

# Crear registry local
docker run -d --restart=always -p 5000:5000 --name kind-registry registry:2

# Conectar registry al cluster de Kind
docker network connect kind kind-registry

# Configurar cluster para usar registry local
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:5000"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
```

#### Uso del Registry Local
```bash
# Construir y subir imagen
docker build -t localhost:5000/my-app:latest .
docker push localhost:5000/my-app:latest

# Usar en deployment
kubectl set image deployment/my-app container=localhost:5000/my-app:latest
```

### 4. Configuración de Volúmenes Host

#### Montaje de Directorios para Desarrollo
```yaml
# kind-host-volumes.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: dev-cluster
nodes:
- role: control-plane
  extraMounts:
  - hostPath: /path/to/local/source
    containerPath: /app/source
  - hostPath: /path/to/local/data
    containerPath: /data
  - hostPath: /path/to/local/logs
    containerPath: /var/log/app
```

```yaml
# pod-with-host-volume-kind.yaml
apiVersion: v1
kind: Pod
metadata:
  name: dev-pod
spec:
  containers:
  - name: app
    image: node:18-alpine
    volumeMounts:
    - name: source-code
      mountPath: /app
    - name: data-storage
      mountPath: /data
  volumes:
  - name: source-code
    hostPath:
      path: /app/source
  - name: data-storage
    hostPath:
      path: /data
```

### 5. Configuración de Red Personalizada

#### Red Custom para Kind
```yaml
# kind-custom-network.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: custom-network-cluster
networking:
  # Deshabilitar CNI por defecto para usar uno custom
  disableDefaultCNI: true
  # Configurar subnet personalizada
  podSubnet: "192.168.0.0/16"
  serviceSubnet: "10.96.0.0/12"
nodes:
- role: control-plane
- role: worker
- role: worker
```

#### Instalación de Calico en Kind
```bash
#!/bin/bash
# install-calico-kind.sh

# Crear cluster sin CNI
kind create cluster --config=kind-custom-network.yaml

# Instalar Calico
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/tigera-operator.yaml

# Configurar Calico para Kind
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
```

### 6. Configuración para CI/CD

#### Cluster Optimizado para CI
```yaml
# kind-ci-config.yaml
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
        # Optimizaciones para CI
        max-pods: "50"
        kube-reserved: "cpu=100m,memory=256Mi"
        system-reserved: "cpu=100m,memory=256Mi"
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
        max-pods: "100"
```

#### Script para CI/CD con Kind
```bash
#!/bin/bash
# ci-with-kind.sh

set -e

CLUSTER_NAME="ci-cluster"
REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5000"

echo "🚀 Setting up Kind cluster for CI/CD..."

# Cleanup previous runs
kind delete cluster --name $CLUSTER_NAME 2>/dev/null || true
docker rm -f $REGISTRY_NAME 2>/dev/null || true

# Start local registry
echo "Starting local registry..."
docker run -d --restart=always -p "$REGISTRY_PORT:5000" --name $REGISTRY_NAME registry:2

# Create cluster
echo "Creating Kind cluster..."
kind create cluster --name $CLUSTER_NAME --config=kind-ci-config.yaml

# Connect registry to cluster network
echo "Connecting registry to cluster..."
docker network connect "kind" $REGISTRY_NAME

# Configure cluster to use local registry
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

# Install ingress controller
echo "Installing NGINX Ingress..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo "✅ Kind cluster ready for CI/CD"
echo "Registry: localhost:${REGISTRY_PORT}"
echo "Cluster: ${CLUSTER_NAME}"
```

### 7. Scripts de Automatización

#### Gestión de Múltiples Clusters
```bash
#!/bin/bash
# multi-cluster-kind.sh

# Función para crear cluster específico
create_cluster() {
    local name=$1
    local config=$2
    
    echo "Creating cluster: $name"
    kind create cluster --name $name --config $config
}

# Crear múltiples clusters para diferentes propósitos
create_cluster "development" "kind-dev-config.yaml"
create_cluster "testing" "kind-test-config.yaml"
create_cluster "staging" "kind-staging-config.yaml"

# Listar clusters
echo "Available clusters:"
kind get clusters

# Función para cambiar entre clusters
switch_cluster() {
    local cluster_name=$1
    kubectl config use-context "kind-$cluster_name"
    echo "Switched to cluster: $cluster_name"
}

# Ejemplo de uso: switch_cluster development
```

#### Backup y Restore de Clusters
```bash
#!/bin/bash
# backup-kind-cluster.sh

CLUSTER_NAME=${1:-kind}
BACKUP_DIR="kind-backups/$(date +%Y%m%d-%H%M%S)"

echo "Creating backup of cluster: $CLUSTER_NAME"
mkdir -p $BACKUP_DIR

# Backup all resources
for resource in $(kubectl api-resources --namespaced=true --verbs=list -o name); do
    echo "Backing up $resource..."
    kubectl get $resource --all-namespaces -o yaml > "$BACKUP_DIR/$resource.yaml" 2>/dev/null || true
done

# Backup cluster-scoped resources
for resource in $(kubectl api-resources --namespaced=false --verbs=list -o name); do
    echo "Backing up $resource..."
    kubectl get $resource -o yaml > "$BACKUP_DIR/cluster-$resource.yaml" 2>/dev/null || true
done

echo "Backup completed: $BACKUP_DIR"
```

## 🔧 Comandos Útiles Específicos de Kind

### Gestión de Clusters
```bash
# Listar clusters
kind get clusters

# Obtener kubeconfig
kind get kubeconfig --name my-cluster

# Cargar imagen Docker en cluster
kind load docker-image my-app:latest --name my-cluster

# SSH al nodo (usando Docker)
docker exec -it my-cluster-control-plane bash
```

### Debugging
```bash
# Ver logs del nodo
docker logs my-cluster-control-plane

# Inspeccionar contenedor del nodo
docker inspect my-cluster-control-plane

# Ver configuración del cluster
kind export kubeconfig --name my-cluster
```

## 📝 Notas Importantes

1. **Rendimiento**: Kind es más rápido que VMs para testing rápido
2. **Isolation**: Cada cluster corre en contenedores separados
3. **Networking**: Configurar port mappings para acceso externo
4. **Storage**: Usar extraMounts para persistencia entre recreaciones
5. **Registry**: Configurar registry local para desarrollo iterativo

## 🔗 Enlaces Útiles

- [Documentación oficial de Kind](https://kind.sigs.k8s.io/)
- [Configuración avanzada](https://kind.sigs.k8s.io/docs/user/configuration/)
- [Registry local](https://kind.sigs.k8s.io/docs/user/local-registry/)
