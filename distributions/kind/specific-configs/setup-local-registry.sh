#!/bin/bash
# setup-local-registry.sh

set -e

REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5000"

echo "🚀 Setting up local Docker registry for Kind..."

# Check if registry already exists
if docker ps -a --format 'table {{.Names}}' | grep -q "^${REGISTRY_NAME}$"; then
    echo "Registry ${REGISTRY_NAME} already exists"
    docker start ${REGISTRY_NAME} 2>/dev/null || true
else
    echo "Creating new registry: ${REGISTRY_NAME}"
    docker run -d --restart=always -p ${REGISTRY_PORT}:5000 --name ${REGISTRY_NAME} registry:2
fi

# Get current Kind cluster name
CLUSTER_NAME=$(kubectl config current-context | sed 's/kind-//')

# Connect registry to kind network if not already connected
if ! docker network inspect kind >/dev/null 2>&1; then
    echo "Kind network not found. Make sure you have a Kind cluster running."
    exit 1
fi

# Connect registry to kind network
echo "Connecting registry to Kind network..."
docker network connect kind ${REGISTRY_NAME} 2>/dev/null || echo "Registry already connected to Kind network"

# Configure cluster to use local registry
echo "Configuring cluster to use local registry..."
cat <<EOF | kubectl apply -f -
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

echo "✅ Local registry setup completed!"
echo ""
echo "Registry URL: localhost:${REGISTRY_PORT}"
echo ""
echo "To use the registry:"
echo "1. Build and tag your image:"
echo "   docker build -t localhost:${REGISTRY_PORT}/my-app:latest ."
echo ""
echo "2. Push the image:"
echo "   docker push localhost:${REGISTRY_PORT}/my-app:latest"
echo ""
echo "3. Use in Kubernetes:"
echo "   kubectl create deployment my-app --image=localhost:${REGISTRY_PORT}/my-app:latest"
