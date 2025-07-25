# Configuraciones Específicas de k3s

Esta carpeta contiene configuraciones y ejemplos que aprovechan características específicas de k3s (Lightweight Kubernetes) que lo diferencian de otras distribuciones.

## 🎯 Contenido Específico de k3s

### 1. Configuración de Traefik (Ingress Nativo)

#### Configuración Personalizada de Traefik
```yaml
# traefik-config.yaml
# k3s viene con Traefik preinstalado, esta configuración lo personaliza
apiVersion: v1
kind: ConfigMap
metadata:
  name: traefik-config
  namespace: kube-system
data:
  traefik.yaml: |
    entryPoints:
      web:
        address: ":80"
      websecure:
        address: ":443"
    certificatesResolvers:
      letsencrypt:
        acme:
          email: admin@example.com
          storage: /data/acme.json
          httpChallenge:
            entryPoint: web
    providers:
      kubernetesingress:
        allowEmptyServices: true
      kubernetescrd:
        allowCrossNamespace: true
```

#### Middleware para Traefik
```yaml
# traefik-middleware.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: auth-middleware
  namespace: default
spec:
  basicAuth:
    secret: auth-secret
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: rate-limit
  namespace: default
spec:
  rateLimit:
    burst: 100
    average: 50
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: compress
  namespace: default
spec:
  compress: {}
```

#### IngressRoute para Traefik (CRD específico)
```yaml
# app-ingressroute.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: api-ingressroute
  namespace: default
spec:
  entryPoints:
    - web
    - websecure
  routes:
  - match: Host(`api.example.com`)
    kind: Rule
    services:
    - name: api-service
      port: 80
    middlewares:
    - name: rate-limit
    - name: compress
  - match: Host(`api.example.com`) && PathPrefix(`/admin`)
    kind: Rule
    services:
    - name: api-service
      port: 80
    middlewares:
    - name: auth-middleware
  tls:
    certResolver: letsencrypt
```

### 2. Configuración de ServiceLB (LoadBalancer Nativo)

#### ServiceLB para Aplicaciones
```yaml
# servicelb-example.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app-lb
  annotations:
    # Específico de k3s ServiceLB
    svccontroller.k3s.cattle.io/enablelb: "true"
    # Asignar IP específica (opcional)
    svccontroller.k3s.cattle.io/lbpool: "192.168.1.100-192.168.1.110"
spec:
  type: LoadBalancer
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 8080
    name: http
  - port: 443
    targetPort: 8443
    name: https
```

#### Configuración de Pool de IPs para ServiceLB
```yaml
# servicelb-ippool.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: servicelb-config
  namespace: kube-system
data:
  config.yaml: |
    pools:
    - name: default
      cidr: 192.168.1.100/28
      avoid-buggy-ips: true
    - name: production
      cidr: 10.0.0.100/28
      avoid-buggy-ips: true
```

### 3. Configuración de Local Storage (Persistencia)

#### Local Path Provisioner (incluido en k3s)
```yaml
# local-storage-class.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

#### Configuración de Directorios para Local Storage
```yaml
# local-path-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-path-config
  namespace: kube-system
data:
  config.json: |
    {
      "nodePathMap": [
        {
          "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES",
          "paths": ["/opt/local-path-provisioner"]
        }
      ]
    }
  setup: |
    #!/bin/sh
    set -eu
    mkdir -m 0777 -p "$VOL_DIR"
  teardown: |
    #!/bin/sh
    set -eu
    rm -rf "$VOL_DIR"
```

#### PVC con Local Storage
```yaml
# app-pvc-local.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-storage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-with-storage
  template:
    metadata:
      labels:
        app: app-with-storage
    spec:
      containers:
      - name: app
        image: nginx:alpine
        volumeMounts:
        - name: data-volume
          mountPath: /data
        ports:
        - containerPort: 80
      volumes:
      - name: data-volume
        persistentVolumeClaim:
          claimName: app-data-pvc
```

### 4. Configuración de Cluster Multi-Nodo

#### Configuración del Servidor Principal
```bash
#!/bin/bash
# k3s-server-setup.sh

# Variables de configuración
K3S_VERSION="v1.28.2+k3s1"
CLUSTER_SECRET="your-secure-token-here"
SERVER_IP=$(hostname -I | cut -d' ' -f1)

echo "Installing k3s server..."

# Instalar k3s como servidor
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION sh -s - \
  --token=$CLUSTER_SECRET \
  --cluster-init \
  --node-name=k3s-server-1 \
  --node-label=role=server \
  --disable=traefik \
  --disable=servicelb \
  --write-kubeconfig-mode=644 \
  --bind-address=$SERVER_IP \
  --advertise-address=$SERVER_IP

# Configurar kubectl
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
chmod 600 ~/.kube/config

echo "k3s server installed successfully!"
echo "Server IP: $SERVER_IP"
echo "Token: $CLUSTER_SECRET"
echo ""
echo "To add nodes, run on other machines:"
echo "curl -sfL https://get.k3s.io | K3S_URL=https://$SERVER_IP:6443 K3S_TOKEN=$CLUSTER_SECRET sh -"
```

#### Configuración de Nodos Worker
```bash
#!/bin/bash
# k3s-agent-setup.sh

# Variables (deben coincidir con el servidor)
SERVER_IP="192.168.1.100"  # IP del servidor k3s
CLUSTER_SECRET="your-secure-token-here"
NODE_NAME=$(hostname)

echo "Installing k3s agent..."

# Instalar k3s como agente
curl -sfL https://get.k3s.io | sh -s - \
  agent \
  --server=https://$SERVER_IP:6443 \
  --token=$CLUSTER_SECRET \
  --node-name=$NODE_NAME \
  --node-label=role=worker

echo "k3s agent installed successfully!"
echo "Node: $NODE_NAME"
echo "Connected to server: $SERVER_IP"
```

### 5. Configuración con Helm (Chart Repository)

#### Configuración de Helm para k3s
```bash
#!/bin/bash
# helm-setup-k3s.sh

echo "Setting up Helm for k3s..."

# Instalar Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Agregar repositorios útiles
helm repo add stable https://charts.helm.sh/stable
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Actualizar repositorios
helm repo update

echo "Helm configured for k3s!"
```

#### Despliegue de NGINX Ingress en k3s
```bash
#!/bin/bash
# install-nginx-ingress.sh

# Como k3s viene con Traefik, necesitamos deshabilitar conflictos
echo "Installing NGINX Ingress Controller..."

# Instalar NGINX Ingress via Helm
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."svccontroller\.k3s\.cattle\.io/enablelb"="true" \
  --set controller.ingressClass="nginx" \
  --set controller.ingressClassResource.default=false

echo "NGINX Ingress installed!"
echo "Waiting for LoadBalancer IP..."

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

kubectl get service -n ingress-nginx
```

### 6. Configuración de Monitoreo (Prometheus/Grafana)

#### Stack de Monitoreo para k3s
```bash
#!/bin/bash
# monitoring-stack-k3s.sh

echo "Installing monitoring stack for k3s..."

# Crear namespace
kubectl create namespace monitoring

# Instalar kube-prometheus-stack
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=local-path \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=20Gi \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.storageClassName=local-path \
  --set grafana.persistence.size=5Gi \
  --set grafana.adminPassword=admin123 \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName=local-path \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage=5Gi

echo "Monitoring stack installed!"
echo "Grafana password: admin123"
```

#### Configuración de Ingress para Monitoreo
```yaml
# monitoring-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: monitoring-ingress
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: "traefik"
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  rules:
  - host: grafana.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-grafana
            port:
              number: 80
  - host: prometheus.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-kube-prometheus-prometheus
            port:
              number: 9090
```

### 7. Configuración de Edge Computing

#### Configuración Optimizada para Edge
```yaml
# k3s-edge-config.yaml
# Configuración para nodos edge con recursos limitados
apiVersion: v1
kind: ConfigMap
metadata:
  name: k3s-edge-config
  namespace: kube-system
data:
  config.yaml: |
    # Configuraciones específicas para edge computing
    kubelet-arg:
    - "max-pods=50"
    - "kube-reserved=cpu=100m,memory=256Mi"
    - "system-reserved=cpu=100m,memory=256Mi"
    - "eviction-hard=memory.available<100Mi"
    - "image-gc-high-threshold=60"
    - "image-gc-low-threshold=40"
    
    kube-controller-manager-arg:
    - "node-monitor-period=10s"
    - "node-monitor-grace-period=30s"
    - "pod-eviction-timeout=1m"
    
    kube-scheduler-arg:
    - "bind-timeout-seconds=5"
```

#### Deployment para Aplicación Edge
```yaml
# edge-app-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: edge-sensor-app
  labels:
    app: edge-sensor
    tier: edge
spec:
  replicas: 1
  selector:
    matchLabels:
      app: edge-sensor
  template:
    metadata:
      labels:
        app: edge-sensor
        tier: edge
    spec:
      nodeSelector:
        node-role.kubernetes.io/edge: "true"
      tolerations:
      - key: "edge"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
      containers:
      - name: sensor-collector
        image: sensor-app:latest
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        env:
        - name: EDGE_MODE
          value: "true"
        - name: DATA_RETENTION_HOURS
          value: "24"
        volumeMounts:
        - name: sensor-data
          mountPath: /data
      volumes:
      - name: sensor-data
        hostPath:
          path: /opt/sensor-data
          type: DirectoryOrCreate
```

### 8. Scripts de Automatización para k3s

#### Instalación Completa Automatizada
```bash
#!/bin/bash
# k3s-complete-setup.sh

set -e

# Configuración
K3S_VERSION="${K3S_VERSION:-v1.28.2+k3s1}"
CLUSTER_NAME="${CLUSTER_NAME:-k3s-cluster}"
INSTALL_MONITORING="${INSTALL_MONITORING:-true}"
INSTALL_INGRESS="${INSTALL_INGRESS:-true}"

echo "🚀 Setting up complete k3s cluster: $CLUSTER_NAME"

# Función para instalar k3s
install_k3s() {
    echo "Installing k3s..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION sh -s - \
        --write-kubeconfig-mode=644 \
        --disable=traefik \
        --disable=servicelb \
        --node-name=$CLUSTER_NAME-master
    
    # Configurar kubectl
    mkdir -p ~/.kube
    cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    chmod 600 ~/.kube/config
    
    echo "✅ k3s installed successfully!"
}

# Función para instalar Helm
install_helm() {
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    # Agregar repositorios
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    echo "✅ Helm installed successfully!"
}

# Función para instalar NGINX Ingress
install_nginx_ingress() {
    if [ "$INSTALL_INGRESS" = "true" ]; then
        echo "Installing NGINX Ingress Controller..."
        helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
            --namespace ingress-nginx \
            --create-namespace \
            --set controller.service.type=LoadBalancer \
            --wait
        
        echo "✅ NGINX Ingress installed successfully!"
    fi
}

# Función para instalar monitoreo
install_monitoring() {
    if [ "$INSTALL_MONITORING" = "true" ]; then
        echo "Installing monitoring stack..."
        kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
        
        helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
            --namespace monitoring \
            --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=local-path \
            --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
            --set grafana.persistence.enabled=true \
            --set grafana.persistence.storageClassName=local-path \
            --set grafana.adminPassword=admin123 \
            --wait
        
        echo "✅ Monitoring stack installed successfully!"
        echo "Grafana password: admin123"
    fi
}

# Función principal
main() {
    echo "Starting k3s setup..."
    
    install_k3s
    sleep 10  # Esperar a que k3s esté listo
    
    install_helm
    install_nginx_ingress
    install_monitoring
    
    echo ""
    echo "🎉 k3s cluster setup completed!"
    echo ""
    echo "Cluster info:"
    kubectl cluster-info
    echo ""
    echo "Nodes:"
    kubectl get nodes
    echo ""
    echo "Services:"
    kubectl get svc --all-namespaces
}

# Ejecutar instalación
main
```

#### Backup y Restore para k3s
```bash
#!/bin/bash
# k3s-backup-restore.sh

BACKUP_DIR="/opt/k3s-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Función de backup
backup_k3s() {
    echo "🔄 Creating k3s backup..."
    
    mkdir -p ${BACKUP_DIR}/${TIMESTAMP}
    
    # Backup etcd snapshot (k3s embebido)
    sudo k3s etcd-snapshot save ${BACKUP_DIR}/${TIMESTAMP}/etcd-snapshot
    
    # Backup configuraciones
    sudo cp -r /etc/rancher/k3s ${BACKUP_DIR}/${TIMESTAMP}/k3s-config
    sudo cp -r /var/lib/rancher/k3s ${BACKUP_DIR}/${TIMESTAMP}/k3s-data
    
    echo "✅ Backup completed: ${BACKUP_DIR}/${TIMESTAMP}"
}

# Función de restore
restore_k3s() {
    local backup_path=$1
    
    if [ -z "$backup_path" ]; then
        echo "Usage: restore_k3s <backup_path>"
        return 1
    fi
    
    echo "🔄 Restoring k3s from: $backup_path"
    
    # Parar k3s
    sudo systemctl stop k3s
    
    # Restaurar desde snapshot
    sudo k3s server --cluster-reset --cluster-reset-restore-path=${backup_path}/etcd-snapshot
    
    echo "✅ Restore completed"
}

# Función de limpieza
cleanup_old_backups() {
    local keep_days=${1:-7}
    echo "🧹 Cleaning backups older than $keep_days days..."
    find ${BACKUP_DIR} -type d -mtime +${keep_days} -exec rm -rf {} \;
    echo "✅ Cleanup completed"
}

# Menú principal
case "${1:-}" in
    backup)
        backup_k3s
        ;;
    restore)
        restore_k3s $2
        ;;
    cleanup)
        cleanup_old_backups $2
        ;;
    *)
        echo "Usage: $0 {backup|restore <path>|cleanup [days]}"
        echo "Examples:"
        echo "  $0 backup"
        echo "  $0 restore /opt/k3s-backups/20231201-120000"
        echo "  $0 cleanup 7"
        exit 1
        ;;
esac
```

## 🔧 Comandos Útiles Específicos de k3s

### Gestión del Cluster
```bash
# Ver estado de k3s
sudo systemctl status k3s

# Reiniciar k3s
sudo systemctl restart k3s

# Ver logs de k3s
sudo journalctl -u k3s -f

# Backup manual
sudo k3s etcd-snapshot save backup-$(date +%Y%m%d-%H%M%S)

# Listar snapshots
sudo k3s etcd-snapshot list
```

### Configuración de Nodos
```bash
# Obtener token para agregar nodos
sudo cat /var/lib/rancher/k3s/server/node-token

# Drenar nodo para mantenimiento
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Reinstalar nodo agente
curl -sfL https://get.k3s.io | K3S_URL=https://server-ip:6443 K3S_TOKEN=node-token sh -
```

## 📝 Notas Importantes

1. **Ligero**: k3s tiene menos de 50MB y usa menos memoria que k8s completo
2. **Traefik**: Viene preinstalado, configurar o deshabilitar según necesidades
3. **ServiceLB**: LoadBalancer integrado que funciona sin MetalLB
4. **Local Storage**: Provisioner integrado para persistencia simple
5. **Edge**: Optimizado para dispositivos edge e IoT
6. **Single Binary**: Todo en un solo binario, fácil instalación y mantenimiento

## 🔗 Enlaces Útiles

- [Documentación oficial de k3s](https://docs.k3s.io/)
- [Configuración avanzada](https://docs.k3s.io/installation/configuration)
- [Traefik en k3s](https://docs.k3s.io/networking#traefik-ingress-controller)
