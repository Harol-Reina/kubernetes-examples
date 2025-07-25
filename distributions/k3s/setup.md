# Configuración y Setup de k3s

k3s es una distribución ligera de Kubernetes diseñada para IoT, Edge Computing y ambientes con recursos limitados. Es totalmente compatible con Kubernetes pero con un footprint significativamente menor.

## Tabla de Contenidos

1. [¿Qué es k3s?](#qué-es-k3s)
2. [Instalación](#instalación)
3. [Configuración Básica](#configuración-básica)
4. [Configuración de Clusters HA](#configuración-de-clusters-ha)
5. [Networking](#networking)
6. [Storage](#storage)
7. [Edge Computing](#edge-computing)
8. [IoT y Embedded](#iot-y-embedded)
9. [Monitoreo y Observabilidad](#monitoreo-y-observabilidad)
10. [Troubleshooting](#troubleshooting)
11. [Mejores Prácticas](#mejores-prácticas)

---

## ¿Qué es k3s?

k3s es una distribución ligera de Kubernetes que reduce significativamente la complejidad y los recursos requeridos, manteniéndose totalmente compatible con la API de Kubernetes.

### Características Principales

- **Ligero**: Binario único de ~50MB
- **Rápido**: Tiempo de arranque en segundos
- **Edge Computing**: Optimizado para IoT y Edge
- **HA Simple**: Alta disponibilidad sin complejidad
- **SQLite**: Base de datos por defecto (también soporta etcd)
- **Containerd**: Runtime de contenedores integrado

### Diferencias con Kubernetes Estándar

| Componente | Kubernetes | k3s |
|------------|------------|-----|
| Tamaño | ~1GB+ | ~50MB |
| Base de datos | etcd | SQLite/etcd |
| Container Runtime | Múltiples | containerd |
| CNI | Calico/Flannel | Flannel |
| Ingress | Ninguno | Traefik |
| Load Balancer | Cloud específico | Klipper |

### Casos de Uso

- **Edge Computing**: Deployments en ubicaciones remotas
- **IoT**: Kubernetes en dispositivos embebidos
- **CI/CD**: Clusters rápidos para testing
- **Development**: Ambiente local ligero
- **Homelab**: Clusters domésticos en Raspberry Pi

---

## Instalación

### 1. Instalación en un Solo Nodo

#### Linux (método más simple)
```bash
# Instalación con script oficial
curl -sfL https://get.k3s.io | sh -

# Verificar instalación
sudo k3s kubectl get nodes

# Obtener kubeconfig para kubectl estándar
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Verificar con kubectl
kubectl get nodes
```

#### Con opciones personalizadas
```bash
# Instalación con configuraciones específicas
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --tls-san $(hostname -I | awk '{print $1}')" sh -

# Deshabilitar componentes opcionales
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --disable servicelb" sh -

# Especificar versión
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.28.4+k3s2" sh -
```

### 2. Instalación Manual

```bash
#!/bin/bash
# install-k3s-manual.sh

set -e

K3S_VERSION="v1.28.4+k3s2"
INSTALL_DIR="/usr/local/bin"

echo "🚀 Instalando k3s $K3S_VERSION..."

# Descargar binario
echo "📥 Descargando k3s..."
wget -q -O k3s https://github.com/k3s-io/k3s/releases/download/$K3S_VERSION/k3s

# Hacer ejecutable y mover
chmod +x k3s
sudo mv k3s $INSTALL_DIR/

# Crear directorios necesarios
sudo mkdir -p /etc/rancher/k3s
sudo mkdir -p /var/lib/rancher/k3s

# Crear archivo de configuración
sudo tee /etc/rancher/k3s/config.yaml > /dev/null <<EOF
write-kubeconfig-mode: "644"
tls-san:
  - "$(hostname -I | awk '{print $1}')"
  - "$(hostname)"
node-label:
  - "node.kubernetes.io/instance-type=standard"
disable:
  - traefik  # Si no quieres Traefik
  - servicelb  # Si prefieres MetalLB
EOF

# Crear servicio systemd
sudo tee /etc/systemd/system/k3s.service > /dev/null <<EOF
[Unit]
Description=Lightweight Kubernetes
Documentation=https://k3s.io
Wants=network-online.target
After=network-online.target

[Service]
Type=exec
EnvironmentFile=-/etc/default/%N
EnvironmentFile=-/etc/sysconfig/%N
EnvironmentFile=-/etc/systemd/system/k3s.service.env
KillMode=process
Delegate=yes
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s
ExecStartPre=/bin/sh -xc '! /usr/bin/systemctl is-enabled --quiet nm-cloud-setup.service'
ExecStartPre=-/sbin/modprobe br_netfilter
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/k3s server
ExecStopPost=/bin/sh -c "systemctl show %n --property=SubState --value | grep -q exited && echo reboot"

[Install]
WantedBy=multi-user.target
EOF

# Habilitar e iniciar servicio
sudo systemctl daemon-reload
sudo systemctl enable k3s
sudo systemctl start k3s

# Configurar kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

echo "✅ k3s instalado y configurado"
echo "🔧 Verifica con: kubectl get nodes"
```

### 3. Instalación en Raspberry Pi

```bash
#!/bin/bash
# install-k3s-rpi.sh

echo "🥧 Instalando k3s en Raspberry Pi..."

# Configuraciones específicas para RPi
echo "⚙️ Configurando sistema para k3s..."

# Habilitar cgroups
if ! grep -q "cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" /boot/cmdline.txt; then
    sudo sed -i 's/$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/' /boot/cmdline.txt
    echo "🔄 Reinicio requerido para habilitar cgroups"
    echo "Ejecuta 'sudo reboot' y luego vuelve a ejecutar este script"
    exit 0
fi

# Instalar k3s con configuraciones para ARM
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --disable=traefik" sh -

# Configurar kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Verificar instalación
kubectl get nodes

echo "✅ k3s instalado en Raspberry Pi"
echo "💡 Considera instalar MetalLB para LoadBalancer support"
```

---

## Configuración Básica

### 1. Configuración Post-instalación

```bash
#!/bin/bash
# k3s-setup.sh

echo "🔧 Configurando k3s..."

# Verificar estado
sudo systemctl status k3s --no-pager

# Obtener token para workers (si vas a agregar nodos)
sudo cat /var/lib/rancher/k3s/server/node-token

# Configurar alias útiles
echo "alias k='kubectl'" >> ~/.bashrc
echo "alias kgs='kubectl get services'" >> ~/.bashrc
echo "alias kgp='kubectl get pods'" >> ~/.bashrc
echo "alias kgn='kubectl get nodes'" >> ~/.bashrc

# Instalar bash completion
kubectl completion bash > ~/.kube/completion.bash.inc
echo "source ~/.kube/completion.bash.inc" >> ~/.bashrc

# Crear namespace de desarrollo
kubectl create namespace development

echo "✅ Configuración básica completada"
```

### 2. Configuración Avanzada

```yaml
# /etc/rancher/k3s/config.yaml
write-kubeconfig-mode: "644"
tls-san:
  - "k3s.local"
  - "192.168.1.100"
disable:
  - traefik
  - servicelb
  - metrics-server  # Si planeas usar otro
node-label:
  - "node.kubernetes.io/instance-type=master"
  - "topology.kubernetes.io/zone=homelab"
cluster-init: true
disable-cloud-controller: true
disable-network-policy: false
flannel-backend: "vxlan"
cluster-cidr: "10.42.0.0/16"
service-cidr: "10.43.0.0/16"
cluster-dns: "10.43.0.10"
node-name: "k3s-master"
```

### 3. Script de Configuración Completa

```bash
#!/bin/bash
# complete-k3s-setup.sh

set -e

NODE_IP=$(hostname -I | awk '{print $1}')
CLUSTER_NAME="homelab"

echo "🚀 Configuración completa de k3s..."
echo "📍 IP del nodo: $NODE_IP"

# 1. Configurar k3s
echo "⚙️ Configurando k3s..."
sudo tee /etc/rancher/k3s/config.yaml > /dev/null <<EOF
write-kubeconfig-mode: "644"
tls-san:
  - "$NODE_IP"
  - "$(hostname)"
  - "k3s.local"
disable:
  - traefik  # Usaremos NGINX
node-label:
  - "node.kubernetes.io/instance-type=master"
  - "cluster=$CLUSTER_NAME"
cluster-cidr: "10.42.0.0/16"
service-cidr: "10.43.0.0/16"
EOF

# 2. Reiniciar k3s para aplicar configuración
sudo systemctl restart k3s
sleep 10

# 3. Configurar kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# 4. Instalar NGINX Ingress
echo "🌐 Instalando NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# 5. Instalar MetalLB
echo "⚖️ Instalando MetalLB..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# Configurar pool de IPs para MetalLB
NETWORK=$(echo $NODE_IP | cut -d'.' -f1-3)
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - ${NETWORK}.200-${NETWORK}.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
EOF

# 6. Instalar Metrics Server
echo "📊 Instalando Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch para que funcione con k3s
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }
]'

# 7. Crear namespaces útiles
echo "📁 Creando namespaces..."
kubectl create namespace development --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# 8. Configurar Local Path Provisioner
echo "💾 Configurando storage..."
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml

# 9. Instalar Dashboard (opcional)
echo "🖥️ Instalando Kubernetes Dashboard..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Crear admin user para dashboard
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

echo "✅ Configuración completa de k3s terminada!"
echo ""
echo "📋 Información útil:"
echo "- Cluster IP: $NODE_IP"
echo "- MetalLB Pool: ${NETWORK}.200-${NETWORK}.250"
echo "- Kubeconfig: ~/.kube/config"
echo ""
echo "🚀 Comandos útiles:"
echo "kubectl get nodes"
echo "kubectl get pods --all-namespaces"
echo "kubectl -n kubernetes-dashboard create token admin-user  # Token para dashboard"
```

---

## Configuración de Clusters HA

### 1. Cluster HA con Base de Datos Externa

```bash
#!/bin/bash
# setup-k3s-ha-external-db.sh

# Variables
DB_HOST="postgres.local"
DB_USER="k3s"
DB_PASSWORD="secure_password"
DB_NAME="k3s"
CLUSTER_SECRET="my-cluster-secret"

# Instalar primer master
echo "🎯 Instalando primer nodo master..."
curl -sfL https://get.k3s.io | sh -s - server \
  --datastore-endpoint="postgres://$DB_USER:$DB_PASSWORD@$DB_HOST:5432/$DB_NAME" \
  --token="$CLUSTER_SECRET" \
  --tls-san="$(hostname -I | awk '{print $1}')" \
  --disable="traefik,servicelb"

# Para nodos master adicionales, usar:
# curl -sfL https://get.k3s.io | sh -s - server \
#   --datastore-endpoint="postgres://$DB_USER:$DB_PASSWORD@$DB_HOST:5432/$DB_NAME" \
#   --token="$CLUSTER_SECRET"
```

### 2. Cluster HA con etcd Embebido

```bash
#!/bin/bash
# setup-k3s-ha-embedded.sh

CLUSTER_SECRET="my-cluster-secret"
MASTER1_IP="192.168.1.10"
MASTER2_IP="192.168.1.11"
MASTER3_IP="192.168.1.12"

# En el primer master
if [ "$(hostname -I | awk '{print $1}')" = "$MASTER1_IP" ]; then
    echo "🎯 Instalando primer master con cluster-init..."
    curl -sfL https://get.k3s.io | sh -s - server \
        --cluster-init \
        --token="$CLUSTER_SECRET" \
        --tls-san="$MASTER1_IP,$MASTER2_IP,$MASTER3_IP" \
        --disable="traefik,servicelb"
fi

# En masters adicionales
if [ "$(hostname -I | awk '{print $1}')" = "$MASTER2_IP" ] || [ "$(hostname -I | awk '{print $1}')" = "$MASTER3_IP" ]; then
    echo "🎯 Uniendo master adicional al cluster..."
    curl -sfL https://get.k3s.io | sh -s - server \
        --server="https://$MASTER1_IP:6443" \
        --token="$CLUSTER_SECRET"
fi
```

### 3. Agregar Nodos Worker

```bash
#!/bin/bash
# add-worker-node.sh

MASTER_IP="192.168.1.10"
NODE_TOKEN="K10xxx::server:xxx"  # Obtener con: sudo cat /var/lib/rancher/k3s/server/node-token

echo "👷 Agregando nodo worker..."

curl -sfL https://get.k3s.io | K3S_URL="https://$MASTER_IP:6443" K3S_TOKEN="$NODE_TOKEN" sh -

# Verificar en el master
# kubectl get nodes
```

---

## Networking

### 1. Configuración de Flannel

```yaml
# /etc/rancher/k3s/config.yaml
flannel-backend: "vxlan"  # o "wireguard", "host-gw"
flannel-iface: "eth0"     # Especificar interfaz de red
cluster-cidr: "10.42.0.0/16"
service-cidr: "10.43.0.0/16"
```

### 2. Deshabilitar Flannel y usar Calico

```bash
#!/bin/bash
# setup-calico.sh

echo "🔗 Configurando Calico en k3s..."

# Instalar k3s sin Flannel
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--flannel-backend=none --disable-network-policy --cluster-cidr=192.168.0.0/16" sh -

# Instalar Calico
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/tigera-operator.yaml

# Configurar Calico
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

echo "✅ Calico configurado"
```

### 3. Configuración de Ingress

```bash
#!/bin/bash
# setup-ingress.sh

echo "🌐 Configurando Ingress..."

# Opción 1: NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Opción 2: Traefik (habilitar si se deshabilitó)
# kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v2.10/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml

# Ejemplo de Ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: app.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: example-service
            port:
              number: 80
EOF

echo "✅ Ingress configurado"
```

---

## Storage

### 1. Local Path Provisioner (por defecto)

```bash
# Ver StorageClass por defecto
kubectl get storageclass

# Ejemplo de PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-path-pvc
  namespace: default
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 2Gi
EOF
```

### 2. Configurar Longhorn para Storage Distribuido

```bash
#!/bin/bash
# setup-longhorn.sh

echo "🐄 Instalando Longhorn..."

# Prerequisitos
sudo apt-get update
sudo apt-get install -y open-iscsi nfs-common

# Instalar Longhorn
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/longhorn.yaml

# Esperar a que esté listo
kubectl -n longhorn-system rollout status deployment/longhorn-manager
kubectl -n longhorn-system rollout status deployment/longhorn-driver-deployer

# Configurar como StorageClass por defecto
kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

echo "✅ Longhorn instalado y configurado como StorageClass por defecto"
```

### 3. Configurar NFS Storage

```bash
#!/bin/bash
# setup-nfs-storage.sh

NFS_SERVER="192.168.1.100"
NFS_PATH="/srv/nfs/k3s"

echo "📁 Configurando NFS Storage..."

# Instalar NFS CSI driver
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/v4.5.0/deploy/install-driver.sh

# Crear StorageClass para NFS
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-csi
provisioner: nfs.csi.k8s.io
parameters:
  server: $NFS_SERVER
  share: $NFS_PATH
reclaimPolicy: Delete
volumeBindingMode: Immediate
mountOptions:
  - nfsvers=4.1
EOF

echo "✅ NFS Storage configurado"
```

---

## Edge Computing

### 1. Configuración para Edge

```yaml
# /etc/rancher/k3s/config.yaml para Edge
write-kubeconfig-mode: "644"
disable:
  - traefik
  - local-storage
node-label:
  - "node.kubernetes.io/instance-type=edge"
  - "topology.kubernetes.io/zone=edge-site-1"
kubelet-arg:
  - "max-pods=50"
  - "eviction-hard=memory.available<100Mi"
  - "system-reserved=cpu=100m,memory=100Mi"
kube-controller-manager-arg:
  - "node-monitor-period=20s"
  - "node-monitor-grace-period=120s"
  - "pod-eviction-timeout=300s"
```

### 2. Deployment para Edge

```yaml
# edge-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: edge-app
  labels:
    app: edge-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: edge-app
  template:
    metadata:
      labels:
        app: edge-app
    spec:
      nodeSelector:
        node.kubernetes.io/instance-type: edge
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
      tolerations:
      - key: "node.kubernetes.io/unreachable"
        operator: "Exists"
        effect: "NoExecute"
        tolerationSeconds: 300
      - key: "node.kubernetes.io/not-ready"
        operator: "Exists"
        effect: "NoExecute"
        tolerationSeconds: 300
```

### 3. DaemonSet para Edge Monitoring

```yaml
# edge-monitoring.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: edge-monitor
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: edge-monitor
  template:
    metadata:
      labels:
        app: edge-monitor
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: monitor
        image: prom/node-exporter:latest
        args:
        - '--path.procfs=/host/proc'
        - '--path.sysfs=/host/sys'
        - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'
        ports:
        - containerPort: 9100
          hostPort: 9100
        resources:
          requests:
            memory: "30Mi"
            cpu: "10m"
          limits:
            memory: "50Mi"
            cpu: "20m"
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      tolerations:
      - effect: NoSchedule
        operator: Exists
```

---

## IoT y Embedded

### 1. Configuración para Raspberry Pi

```bash
#!/bin/bash
# k3s-rpi-optimization.sh

echo "🥧 Optimizando k3s para Raspberry Pi..."

# Configuración específica para RPi
sudo tee /etc/rancher/k3s/config.yaml > /dev/null <<EOF
write-kubeconfig-mode: "644"
disable:
  - traefik
  - servicelb
  - metrics-server
node-label:
  - "node.kubernetes.io/instance-type=raspberry-pi"
  - "hardware=arm64"
kubelet-arg:
  - "max-pods=30"
  - "eviction-hard=memory.available<100Mi"
  - "system-reserved=cpu=100m,memory=100Mi"
  - "image-gc-high-threshold=70"
  - "image-gc-low-threshold=60"
kube-apiserver-arg:
  - "default-not-ready-toleration-seconds=300"
  - "default-unreachable-toleration-seconds=300"
EOF

# Optimizaciones del sistema
echo "⚙️ Aplicando optimizaciones del sistema..."

# Configurar swap
sudo dphys-swapfile swapoff
sudo systemctl disable dphys-swapfile

# Configurar GPU memory split
echo "gpu_mem=16" | sudo tee -a /boot/config.txt

# Configurar cgroups si no está habilitado
if ! grep -q "cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" /boot/cmdline.txt; then
    sudo sed -i 's/$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/' /boot/cmdline.txt
fi

echo "✅ Optimizaciones aplicadas. Reinicia el sistema."
```

### 2. Deployment para IoT

```yaml
# iot-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: iot-collector
spec:
  replicas: 1
  selector:
    matchLabels:
      app: iot-collector
  template:
    metadata:
      labels:
        app: iot-collector
    spec:
      nodeSelector:
        hardware: arm64
      containers:
      - name: collector
        image: iot-collector:arm64
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"
        env:
        - name: MQTT_BROKER
          value: "mosquitto.iot.svc.cluster.local"
        - name: INFLUXDB_URL
          value: "http://influxdb.iot.svc.cluster.local:8086"
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: device
          mountPath: /dev/ttyUSB0
        securityContext:
          privileged: true  # Para acceso a dispositivos
      volumes:
      - name: device
        hostPath:
          path: /dev/ttyUSB0
          type: CharDevice
```

### 3. MQTT y Time Series para IoT

```yaml
# iot-stack.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mosquitto
  namespace: iot
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mosquitto
  template:
    metadata:
      labels:
        app: mosquitto
    spec:
      containers:
      - name: mosquitto
        image: eclipse-mosquitto:2.0
        ports:
        - containerPort: 1883
        - containerPort: 9001
        volumeMounts:
        - name: config
          mountPath: /mosquitto/config
        - name: data
          mountPath: /mosquitto/data
      volumes:
      - name: config
        configMap:
          name: mosquitto-config
      - name: data
        persistentVolumeClaim:
          claimName: mosquitto-pvc
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: influxdb
  namespace: iot
spec:
  replicas: 1
  selector:
    matchLabels:
      app: influxdb
  template:
    metadata:
      labels:
        app: influxdb
    spec:
      containers:
      - name: influxdb
        image: influxdb:2.7-alpine
        ports:
        - containerPort: 8086
        env:
        - name: DOCKER_INFLUXDB_INIT_MODE
          value: "setup"
        - name: DOCKER_INFLUXDB_INIT_USERNAME
          value: "admin"
        - name: DOCKER_INFLUXDB_INIT_PASSWORD
          value: "password"
        - name: DOCKER_INFLUXDB_INIT_ORG
          value: "iot"
        - name: DOCKER_INFLUXDB_INIT_BUCKET
          value: "sensors"
        volumeMounts:
        - name: data
          mountPath: /var/lib/influxdb2
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: influxdb-pvc
```

---

## Monitoreo y Observabilidad

### 1. Prometheus Stack Ligero

```bash
#!/bin/bash
# setup-monitoring.sh

echo "📊 Instalando stack de monitoreo ligero..."

# Crear namespace
kubectl create namespace monitoring

# Instalar kube-prometheus-stack ligero
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.resources.requests.memory="400Mi" \
  --set prometheus.prometheusSpec.resources.limits.memory="800Mi" \
  --set prometheus.prometheusSpec.resources.requests.cpu="200m" \
  --set prometheus.prometheusSpec.resources.limits.cpu="400m" \
  --set grafana.resources.requests.memory="200Mi" \
  --set grafana.resources.limits.memory="400Mi" \
  --set alertmanager.enabled=false

echo "✅ Monitoreo instalado"
```

### 2. Configuración de Alertas

```yaml
# k3s-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: k3s-alerts
  namespace: monitoring
spec:
  groups:
  - name: k3s.rules
    rules:
    - alert: K3sNodeDown
      expr: up{job="node-exporter"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "k3s node is down"
        description: "Node {{ $labels.instance }} has been down for more than 5 minutes"
        
    - alert: K3sHighMemoryUsage
      expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage on k3s node"
        description: "Memory usage is above 90% on {{ $labels.instance }}"
        
    - alert: K3sHighCPUUsage
      expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High CPU usage on k3s node"
        description: "CPU usage is above 80% on {{ $labels.instance }}"
```

### 3. Dashboard Personalizado para k3s

```json
{
  "dashboard": {
    "id": null,
    "title": "k3s Cluster Overview",
    "tags": ["k3s", "kubernetes"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Cluster Nodes",
        "type": "stat",
        "targets": [
          {
            "expr": "count(up{job=\"node-exporter\"})",
            "legendFormat": "Total Nodes"
          },
          {
            "expr": "count(up{job=\"node-exporter\"} == 1)",
            "legendFormat": "Healthy Nodes"
          }
        ]
      },
      {
        "id": 2,
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
            "legendFormat": "{{ instance }}"
          }
        ]
      },
      {
        "id": 3,
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "{{ instance }}"
          }
        ]
      }
    ]
  }
}
```

---

## Troubleshooting

### 1. Comandos de Diagnóstico

```bash
#!/bin/bash
# k3s-diagnostics.sh

echo "🔍 Diagnósticos de k3s..."

# Estado del servicio
echo "=== Estado del servicio k3s ==="
sudo systemctl status k3s --no-pager

# Logs del servicio
echo "=== Logs de k3s (últimas 50 líneas) ==="
sudo journalctl -u k3s --no-pager -n 50

# Estado del cluster
echo "=== Estado del cluster ==="
kubectl get nodes -o wide

# Pods del sistema
echo "=== Pods del sistema ==="
kubectl get pods -n kube-system

# Recursos del sistema
echo "=== Uso de recursos ==="
free -h
df -h
top -bn1 | head -20

# Configuración de red
echo "=== Configuración de red ==="
ip addr show
ip route show

# Logs de containerd
echo "=== Logs de containerd ==="
sudo journalctl -u containerd --no-pager -n 20

echo "✅ Diagnósticos completados"
```

### 2. Problemas Comunes

#### Node NotReady
```bash
# Verificar logs
sudo journalctl -u k3s -f

# Verificar espacio en disco
df -h /var/lib/rancher

# Limpiar imágenes no utilizadas
sudo k3s crictl images prune

# Reiniciar servicio
sudo systemctl restart k3s
```

#### Pods en estado Pending
```bash
# Verificar recursos
kubectl describe node

# Verificar tolerations y node selectors
kubectl describe pod <pod-name>

# Verificar storage
kubectl get pv,pvc
```

#### Problemas de Red
```bash
# Verificar CNI
kubectl get pods -n kube-system | grep flannel

# Verificar conectividad entre pods
kubectl run debug --image=nicolaka/netshoot -it --rm

# Verificar DNS
kubectl run debug --image=busybox -it --rm -- nslookup kubernetes.default
```

### 3. Script de Reparación Automática

```bash
#!/bin/bash
# k3s-repair.sh

echo "🔧 Reparación automática de k3s..."

# Verificar espacio en disco
DISK_USAGE=$(df /var/lib/rancher | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "⚠️ Espacio en disco bajo, limpiando..."
    sudo k3s crictl images prune
    sudo k3s crictl rmi --prune
fi

# Verificar memoria
FREE_MEM=$(free | grep Mem | awk '{print int($4/$2*100)}')
if [ $FREE_MEM -lt 10 ]; then
    echo "⚠️ Memoria baja, limpiando cache..."
    sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
fi

# Verificar que k3s esté corriendo
if ! sudo systemctl is-active --quiet k3s; then
    echo "🔄 Reiniciando k3s..."
    sudo systemctl restart k3s
    sleep 30
fi

# Verificar nodos
if ! kubectl get nodes &>/dev/null; then
    echo "🔄 Problema de conectividad, reiniciando..."
    sudo systemctl restart k3s
fi

echo "✅ Reparación completada"
```

---

## Mejores Prácticas

### 1. Configuración de Producción

```yaml
# /etc/rancher/k3s/config.yaml para producción
write-kubeconfig-mode: "644"
tls-san:
  - "k3s-api.company.com"
  - "192.168.1.10"
disable:
  - traefik  # Usar NGINX Ingress
  - local-storage  # Usar Longhorn
secrets-encryption: true
protect-kernel-defaults: true
kube-apiserver-arg:
  - "audit-log-path=/var/log/audit.log"
  - "audit-log-maxage=30"
  - "audit-log-maxbackup=10"
  - "audit-log-maxsize=100"
  - "enable-admission-plugins=NodeRestriction,PodSecurityPolicy"
kubelet-arg:
  - "protect-kernel-defaults=true"
  - "read-only-port=0"
  - "streaming-connection-idle-timeout=5m"
```

### 2. Backup y Restore

```bash
#!/bin/bash
# backup-k3s.sh

BACKUP_DIR="/backup/k3s"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p $BACKUP_DIR

echo "💾 Creando backup de k3s..."

# Backup de etcd/SQLite
if [ -f "/var/lib/rancher/k3s/server/db/state.db" ]; then
    # SQLite backup
    sudo sqlite3 /var/lib/rancher/k3s/server/db/state.db ".backup $BACKUP_DIR/state-$DATE.db"
else
    # etcd backup
    sudo k3s etcd-snapshot save $BACKUP_DIR/etcd-$DATE
fi

# Backup de configuración
sudo cp -r /etc/rancher/k3s $BACKUP_DIR/config-$DATE

# Backup de manifiestos
sudo cp -r /var/lib/rancher/k3s/server/manifests $BACKUP_DIR/manifests-$DATE

echo "✅ Backup creado en $BACKUP_DIR"
```

### 3. Actualizaciones

```bash
#!/bin/bash
# update-k3s.sh

TARGET_VERSION=${1:-"latest"}

echo "🔄 Actualizando k3s a versión $TARGET_VERSION..."

# Backup antes de actualizar
./backup-k3s.sh

# Actualizar k3s
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$TARGET_VERSION" sh -s - server

# Verificar actualización
kubectl version
kubectl get nodes

echo "✅ Actualización completada"
```

### 4. Monitoreo de Recursos

```bash
#!/bin/bash
# monitor-k3s.sh

echo "📊 Monitoreo de recursos k3s..."

# Función para convertir bytes a formato legible
human_readable() {
    local bytes=$1
    local sizes=("B" "KB" "MB" "GB" "TB")
    local i=0
    
    while [[ $bytes -gt 1024 && $i -lt 4 ]]; do
        bytes=$((bytes / 1024))
        ((i++))
    done
    
    echo "${bytes}${sizes[$i]}"
}

# Uso de CPU y memoria
echo "=== Uso de recursos del sistema ==="
echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "Memoria: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"

# Espacio en disco
echo "=== Espacio en disco ==="
df -h /var/lib/rancher

# Pods por nodo
echo "=== Pods por nodo ==="
kubectl get pods --all-namespaces -o wide | awk '{print $8}' | sort | uniq -c

# Top pods por uso de CPU y memoria
echo "=== Top pods por recursos ==="
kubectl top pods --all-namespaces --sort-by=memory | head -10

echo "✅ Monitoreo completado"
```

k3s es una excelente opción para casos de uso donde necesitas Kubernetes con un footprint menor, especialmente en edge computing, IoT, y entornos con recursos limitados. Su simplicidad de instalación y gestión lo hace ideal para equipos que quieren las capacidades de Kubernetes sin la complejidad operacional.
