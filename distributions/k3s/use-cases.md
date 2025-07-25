# Casos de Uso de k3s

Este documento presenta casos de uso prácticos y detallados para k3s, desde implementaciones básicas hasta escenarios avanzados de edge computing e IoT.

## Tabla de Contenidos

1. [Edge Computing](#edge-computing)
2. [IoT y Dispositivos Embebidos](#iot-y-dispositivos-embebidos)
3. [Home Lab y Aprendizaje](#home-lab-y-aprendizaje)
4. [CI/CD Ligero](#cicd-ligero)
5. [Desarrollo Local](#desarrollo-local)
6. [Retail y Punto de Venta](#retail-y-punto-de-venta)
7. [Monitoreo y Telemetría](#monitoreo-y-telemetría)
8. [Aplicaciones Industriales](#aplicaciones-industriales)
9. [Edge AI y Machine Learning](#edge-ai-y-machine-learning)
10. [Cluster Multi-Sitio](#cluster-multi-sitio)

---

## Edge Computing

### Caso de Uso: Centro de Distribución Automatizado

**Escenario**: Una empresa de logística necesita procesar datos en tiempo real en sus centros de distribución remotos, donde la conectividad a la nube puede ser intermitente.

#### Arquitectura

```yaml
# edge-warehouse-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: warehouse-management
  namespace: logistics
  labels:
    app: warehouse-management
    tier: edge
spec:
  replicas: 2
  selector:
    matchLabels:
      app: warehouse-management
  template:
    metadata:
      labels:
        app: warehouse-management
    spec:
      nodeSelector:
        location: warehouse
        zone: edge
      containers:
      - name: wms-core
        image: warehouse/wms:v2.1
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        env:
        - name: DB_HOST
          value: "postgresql.logistics.svc.cluster.local"
        - name: REDIS_HOST
          value: "redis.logistics.svc.cluster.local"
        - name: EDGE_MODE
          value: "true"
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: local-cache
          mountPath: /var/cache/wms
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
      - name: barcode-scanner
        image: warehouse/scanner-service:v1.5
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        env:
        - name: SCANNER_DEVICE
          value: "/dev/ttyUSB0"
        volumeMounts:
        - name: scanner-device
          mountPath: /dev/ttyUSB0
        securityContext:
          privileged: true
      volumes:
      - name: local-cache
        hostPath:
          path: /opt/warehouse/cache
          type: DirectoryOrCreate
      - name: scanner-device
        hostPath:
          path: /dev/ttyUSB0
          type: CharDevice
      tolerations:
      - key: "edge.warehouse.com/connectivity"
        operator: "Exists"
        effect: "NoSchedule"
---
apiVersion: v1
kind: Service
metadata:
  name: warehouse-management
  namespace: logistics
spec:
  selector:
    app: warehouse-management
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
---
# Base de datos local para cache offline
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
  namespace: logistics
spec:
  serviceName: postgresql
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: postgres:15-alpine
        env:
        - name: POSTGRES_DB
          value: warehouse
        - name: POSTGRES_USER
          value: wms_user
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "300m"
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: local-path
      resources:
        requests:
          storage: 10Gi
```

#### Configuración de Red para Edge

```yaml
# edge-network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: warehouse-network-policy
  namespace: logistics
spec:
  podSelector:
    matchLabels:
      tier: edge
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: logistics
    - podSelector:
        matchLabels:
          app: nginx-ingress
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: logistics
    ports:
    - protocol: TCP
      port: 5432  # PostgreSQL
    - protocol: TCP
      port: 6379  # Redis
  - to: []  # Permitir tráfico a internet para actualizaciones
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
```

#### Scripts de Deployment

```bash
#!/bin/bash
# deploy-warehouse-edge.sh

set -e

NAMESPACE="logistics"
LOCATION="${1:-warehouse-01}"

echo "🏭 Desplegando solución de warehouse edge en $LOCATION..."

# Crear namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Etiquetar nodos
kubectl label nodes --all location=$LOCATION --overwrite
kubectl label nodes --all zone=edge --overwrite

# Crear secretos
kubectl create secret generic db-credentials \
  --from-literal=password=$(openssl rand -base64 32) \
  --namespace=$NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

# Desplegar aplicaciones
kubectl apply -f edge-warehouse-deployment.yaml
kubectl apply -f edge-network-policy.yaml

# Verificar deployment
echo "⏳ Esperando a que los pods estén listos..."
kubectl wait --for=condition=ready pod -l app=warehouse-management -n $NAMESPACE --timeout=300s

echo "✅ Deployment de warehouse edge completado"
echo "📍 Ubicación: $LOCATION"
echo "🔗 Verificar con: kubectl get pods -n $NAMESPACE"
```

---

## IoT y Dispositivos Embebidos

### Caso de Uso: Monitoreo de Invernaderos Inteligentes

**Escenario**: Red de invernaderos que requiere monitoreo en tiempo real de temperatura, humedad, pH del suelo y control automatizado de riego.

#### Arquitectura IoT

```yaml
# greenhouse-iot-stack.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: greenhouse-iot
---
# Broker MQTT para sensores
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mosquitto
  namespace: greenhouse-iot
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
          name: mqtt
        - containerPort: 9001
          name: websocket
        volumeMounts:
        - name: mosquitto-config
          mountPath: /mosquitto/config
        - name: mosquitto-data
          mountPath: /mosquitto/data
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      - name: mosquitto-config
        configMap:
          name: mosquitto-config
      - name: mosquitto-data
        persistentVolumeClaim:
          claimName: mosquitto-pvc
---
# Collector de datos de sensores
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sensor-collector
  namespace: greenhouse-iot
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sensor-collector
  template:
    metadata:
      labels:
        app: sensor-collector
    spec:
      containers:
      - name: collector
        image: greenhouse/sensor-collector:v1.2
        env:
        - name: MQTT_BROKER
          value: "mosquitto.greenhouse-iot.svc.cluster.local:1883"
        - name: INFLUXDB_URL
          value: "http://influxdb.greenhouse-iot.svc.cluster.local:8086"
        - name: GREENHOUSE_ID
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        volumeMounts:
        - name: sensor-config
          mountPath: /app/config
      volumes:
      - name: sensor-config
        configMap:
          name: sensor-config
---
# InfluxDB para almacenar datos de sensores
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: influxdb
  namespace: greenhouse-iot
spec:
  serviceName: influxdb
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
          value: "greenhouse"
        - name: DOCKER_INFLUXDB_INIT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: influxdb-auth
              key: password
        - name: DOCKER_INFLUXDB_INIT_ORG
          value: "agriculture"
        - name: DOCKER_INFLUXDB_INIT_BUCKET
          value: "sensors"
        - name: DOCKER_INFLUXDB_INIT_ADMIN_TOKEN
          valueFrom:
            secretKeyRef:
              name: influxdb-auth
              key: admin-token
        volumeMounts:
        - name: influxdb-storage
          mountPath: /var/lib/influxdb2
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "500m"
  volumeClaimTemplates:
  - metadata:
      name: influxdb-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: local-path
      resources:
        requests:
          storage: 20Gi
---
# Sistema de control automatizado
apiVersion: apps/v1
kind: Deployment
metadata:
  name: automation-controller
  namespace: greenhouse-iot
spec:
  replicas: 1
  selector:
    matchLabels:
      app: automation-controller
  template:
    metadata:
      labels:
        app: automation-controller
    spec:
      hostNetwork: true  # Para acceso a GPIO
      containers:
      - name: controller
        image: greenhouse/automation:v2.0
        env:
        - name: INFLUXDB_URL
          value: "http://influxdb.greenhouse-iot.svc.cluster.local:8086"
        - name: INFLUXDB_TOKEN
          valueFrom:
            secretKeyRef:
              name: influxdb-auth
              key: admin-token
        - name: MQTT_BROKER
          value: "mosquitto.greenhouse-iot.svc.cluster.local:1883"
        volumeMounts:
        - name: gpio-access
          mountPath: /dev/gpiomem
        - name: automation-rules
          mountPath: /app/rules
        securityContext:
          privileged: true
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: gpio-access
        hostPath:
          path: /dev/gpiomem
          type: CharDevice
      - name: automation-rules
        configMap:
          name: automation-rules
```

#### Configuración de Sensores

```yaml
# sensor-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: sensor-config
  namespace: greenhouse-iot
data:
  sensors.yaml: |
    sensors:
      - id: "temp_01"
        type: "DHT22"
        gpio_pin: 4
        interval: 30
        metrics:
          - temperature
          - humidity
      - id: "soil_01"
        type: "soil_moisture"
        gpio_pin: 18
        interval: 60
        metrics:
          - moisture
          - ph
      - id: "light_01"
        type: "BH1750"
        i2c_address: 0x23
        interval: 120
        metrics:
          - light_intensity
    mqtt:
      topic_prefix: "greenhouse/sensors"
      qos: 1
      retain: true
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: automation-rules
  namespace: greenhouse-iot
data:
  rules.yaml: |
    rules:
      - name: "irrigation_control"
        condition:
          - sensor: "soil_01"
            metric: "moisture"
            operator: "<"
            value: 30
        actions:
          - type: "gpio_output"
            pin: 23
            duration: 300  # 5 minutos
            message: "Activating irrigation system"
      - name: "temperature_alert"
        condition:
          - sensor: "temp_01"
            metric: "temperature"
            operator: ">"
            value: 35
        actions:
          - type: "notification"
            method: "mqtt"
            topic: "alerts/temperature"
            message: "High temperature detected"
      - name: "humidity_control"
        condition:
          - sensor: "temp_01"
            metric: "humidity"
            operator: "<"
            value: 60
        actions:
          - type: "gpio_output"
            pin: 24
            duration: 600  # 10 minutos
            message: "Activating humidifier"
```

#### Dashboard de Monitoreo

```yaml
# grafana-greenhouse.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: greenhouse-iot
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:10.2.0
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-auth
              key: admin-password
        - name: GF_INSTALL_PLUGINS
          value: "grafana-worldmap-panel,briangann-gauge-panel"
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
        - name: grafana-config
          mountPath: /etc/grafana/provisioning
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "300m"
      volumes:
      - name: grafana-storage
        persistentVolumeClaim:
          claimName: grafana-pvc
      - name: grafana-config
        configMap:
          name: grafana-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-config
  namespace: greenhouse-iot
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
    - name: InfluxDB
      type: influxdb
      access: proxy
      url: http://influxdb.greenhouse-iot.svc.cluster.local:8086
      jsonData:
        version: Flux
        organization: agriculture
        defaultBucket: sensors
      secureJsonData:
        token: ${INFLUXDB_TOKEN}
  dashboards.yaml: |
    apiVersion: 1
    providers:
    - name: 'greenhouse'
      folder: ''
      type: file
      options:
        path: /var/lib/grafana/dashboards
```

#### Script de Deployment IoT

```bash
#!/bin/bash
# deploy-greenhouse-iot.sh

set -e

GREENHOUSE_ID="${1:-greenhouse-001}"
ADMIN_PASSWORD="${2:-$(openssl rand -base64 12)}"

echo "🌱 Desplegando sistema IoT para invernadero $GREENHOUSE_ID..."

# Crear namespace
kubectl create namespace greenhouse-iot --dry-run=client -o yaml | kubectl apply -f -

# Crear secretos
kubectl create secret generic influxdb-auth \
  --from-literal=password="$ADMIN_PASSWORD" \
  --from-literal=admin-token="$(openssl rand -base64 32)" \
  --namespace=greenhouse-iot \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic grafana-auth \
  --from-literal=admin-password="$ADMIN_PASSWORD" \
  --namespace=greenhouse-iot \
  --dry-run=client -o yaml | kubectl apply -f -

# Crear PVCs
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mosquitto-pvc
  namespace: greenhouse-iot
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-pvc
  namespace: greenhouse-iot
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 5Gi
EOF

# Configurar MQTT
kubectl create configmap mosquitto-config \
  --from-literal=mosquitto.conf="
listener 1883
allow_anonymous true
listener 9001
protocol websockets" \
  --namespace=greenhouse-iot \
  --dry-run=client -o yaml | kubectl apply -f -

# Aplicar configuraciones
kubectl apply -f sensor-config.yaml
kubectl apply -f greenhouse-iot-stack.yaml
kubectl apply -f grafana-greenhouse.yaml

# Esperar a que todo esté listo
echo "⏳ Esperando a que los servicios estén listos..."
kubectl wait --for=condition=ready pod -l app=mosquitto -n greenhouse-iot --timeout=300s
kubectl wait --for=condition=ready pod -l app=influxdb -n greenhouse-iot --timeout=300s

echo "✅ Sistema IoT de invernadero desplegado"
echo "🏠 Invernadero ID: $GREENHOUSE_ID"
echo "🔑 Password de admin: $ADMIN_PASSWORD"
echo "📊 Acceso a Grafana: kubectl port-forward -n greenhouse-iot svc/grafana 3000:3000"
echo "📡 MQTT Broker: kubectl port-forward -n greenhouse-iot svc/mosquitto 1883:1883"
```

---

## Home Lab y Aprendizaje

### Caso de Uso: Laboratorio Doméstico de Aprendizaje

**Escenario**: Configurar un entorno de aprendizaje completo para estudiantes y profesionales que quieren practicar con Kubernetes en casa usando Raspberry Pi.

#### Cluster Multi-Nodo en Raspberry Pi

```bash
#!/bin/bash
# setup-homelab-cluster.sh

set -e

MASTER_IP="${1:-192.168.1.10}"
NODE_COUNT="${2:-3}"

echo "🏠 Configurando Home Lab k3s con $NODE_COUNT nodos..."

# Función para configurar master
setup_master() {
    echo "🎯 Configurando nodo master en $MASTER_IP..."
    
    # Configuración optimizada para RPi
    sudo tee /etc/rancher/k3s/config.yaml > /dev/null <<EOF
write-kubeconfig-mode: "644"
tls-san:
  - "$MASTER_IP"
  - "homelab.local"
disable:
  - traefik  # Instalaremos NGINX
node-label:
  - "node.kubernetes.io/instance-type=raspberry-pi"
  - "homelab.local/role=master"
kubelet-arg:
  - "max-pods=50"
  - "eviction-hard=memory.available<100Mi"
  - "system-reserved=cpu=100m,memory=100Mi"
cluster-init: true
EOF

    # Instalar k3s
    curl -sfL https://get.k3s.io | sh -
    
    # Configurar kubectl
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
    
    # Obtener token para workers
    sudo cat /var/lib/rancher/k3s/server/node-token > /tmp/node-token
    
    echo "✅ Master configurado. Token guardado en /tmp/node-token"
}

# Función para configurar worker
setup_worker() {
    local worker_ip="$1"
    local node_token="$2"
    
    echo "👷 Configurando worker en $worker_ip..."
    
    # Configuración para worker
    sudo tee /etc/rancher/k3s/config.yaml > /dev/null <<EOF
node-label:
  - "node.kubernetes.io/instance-type=raspberry-pi"
  - "homelab.local/role=worker"
kubelet-arg:
  - "max-pods=30"
  - "eviction-hard=memory.available<50Mi"
  - "system-reserved=cpu=50m,memory=50Mi"
EOF

    # Unir al cluster
    curl -sfL https://get.k3s.io | K3S_URL="https://$MASTER_IP:6443" K3S_TOKEN="$node_token" sh -
    
    echo "✅ Worker $worker_ip unido al cluster"
}

# Detectar si es master o worker basado en IP
CURRENT_IP=$(hostname -I | awk '{print $1}')

if [ "$CURRENT_IP" = "$MASTER_IP" ]; then
    setup_master
else
    # Obtener token del master
    TOKEN=$(ssh pi@$MASTER_IP "sudo cat /var/lib/rancher/k3s/server/node-token" 2>/dev/null || echo "")
    if [ -z "$TOKEN" ]; then
        echo "❌ No se pudo obtener el token del master. Asegúrate de que el master esté configurado."
        exit 1
    fi
    setup_worker "$CURRENT_IP" "$TOKEN"
fi

echo "🏁 Configuración de nodo completada"
```

#### Stack de Aprendizaje Completo

```yaml
# homelab-learning-stack.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: learning
---
# WordPress para documentación y blog
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: learning
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
      - name: wordpress
        image: wordpress:6.4-apache
        ports:
        - containerPort: 80
        env:
        - name: WORDPRESS_DB_HOST
          value: "mysql.learning.svc.cluster.local"
        - name: WORDPRESS_DB_USER
          value: "wordpress"
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        - name: WORDPRESS_DB_NAME
          value: "wordpress"
        volumeMounts:
        - name: wordpress-storage
          mountPath: /var/www/html
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: wordpress-storage
        persistentVolumeClaim:
          claimName: wordpress-pvc
---
# MySQL para WordPress
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
  namespace: learning
spec:
  serviceName: mysql
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        ports:
        - containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: root-password
        - name: MYSQL_DATABASE
          value: "wordpress"
        - name: MYSQL_USER
          value: "wordpress"
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "500m"
  volumeClaimTemplates:
  - metadata:
      name: mysql-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: local-path
      resources:
        requests:
          storage: 10Gi
---
# Jupyter Lab para experimentos
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jupyterlab
  namespace: learning
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jupyterlab
  template:
    metadata:
      labels:
        app: jupyterlab
    spec:
      containers:
      - name: jupyterlab
        image: jupyter/datascience-notebook:latest
        ports:
        - containerPort: 8888
        env:
        - name: JUPYTER_ENABLE_LAB
          value: "yes"
        - name: JUPYTER_TOKEN
          valueFrom:
            secretKeyRef:
              name: jupyter-secret
              key: token
        volumeMounts:
        - name: jupyter-work
          mountPath: /home/jovyan/work
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      volumes:
      - name: jupyter-work
        persistentVolumeClaim:
          claimName: jupyter-pvc
---
# GitLab CE para control de versiones
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitlab
  namespace: learning
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gitlab
  template:
    metadata:
      labels:
        app: gitlab
    spec:
      containers:
      - name: gitlab
        image: gitlab/gitlab-ce:16.6.1-ce.0
        ports:
        - containerPort: 80
        - containerPort: 22
        env:
        - name: GITLAB_OMNIBUS_CONFIG
          value: |
            external_url 'http://gitlab.homelab.local'
            gitlab_rails['gitlab_shell_ssh_port'] = 2222
        volumeMounts:
        - name: gitlab-config
          mountPath: /etc/gitlab
        - name: gitlab-logs
          mountPath: /var/log/gitlab
        - name: gitlab-data
          mountPath: /var/opt/gitlab
        resources:
          requests:
            memory: "2Gi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
      volumes:
      - name: gitlab-config
        persistentVolumeClaim:
          claimName: gitlab-config-pvc
      - name: gitlab-logs
        persistentVolumeClaim:
          claimName: gitlab-logs-pvc
      - name: gitlab-data
        persistentVolumeClaim:
          claimName: gitlab-data-pvc
---
# Prometheus para monitoreo
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: learning
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:v2.48.0
        ports:
        - containerPort: 9090
        args:
        - '--config.file=/etc/prometheus/prometheus.yml'
        - '--storage.tsdb.path=/prometheus/'
        - '--web.console.libraries=/etc/prometheus/console_libraries'
        - '--web.console.templates=/etc/prometheus/consoles'
        - '--storage.tsdb.retention.time=15d'
        - '--web.enable-lifecycle'
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus/
        - name: prometheus-storage
          mountPath: /prometheus/
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
      - name: prometheus-storage
        persistentVolumeClaim:
          claimName: prometheus-pvc
```

#### Configuración de Networking para Home Lab

```yaml
# homelab-networking.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: learning
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
    - job_name: 'kubernetes-nodes'
      kubernetes_sd_configs:
      - role: node
      relabel_configs:
      - source_labels: [__address__]
        regex: '(.*):10250'
        target_label: __address__
        replacement: '${1}:9100'
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
---
# Ingress para acceso fácil
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: homelab-ingress
  namespace: learning
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: wordpress.homelab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: wordpress
            port:
              number: 80
  - host: jupyter.homelab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: jupyterlab
            port:
              number: 8888
  - host: gitlab.homelab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: gitlab
            port:
              number: 80
  - host: prometheus.homelab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus
            port:
              number: 9090
```

---

## CI/CD Ligero

### Caso de Uso: Pipeline de CI/CD para Microservicios

**Escenario**: Empresa pequeña que necesita un sistema de CI/CD completo pero ligero para desarrollar y desplegar microservicios.

#### Jenkins en k3s

```yaml
# jenkins-cicd.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cicd
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: cicd
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      serviceAccountName: jenkins
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts
        ports:
        - containerPort: 8080
        - containerPort: 50000
        env:
        - name: JAVA_OPTS
          value: "-Xmx1024m -Djenkins.install.runSetupWizard=false"
        - name: JENKINS_ADMIN_ID
          value: "admin"
        - name: JENKINS_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: jenkins-secret
              key: admin-password
        volumeMounts:
        - name: jenkins-home
          mountPath: /var/jenkins_home
        - name: docker-sock
          mountPath: /var/run/docker.sock
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      volumes:
      - name: jenkins-home
        persistentVolumeClaim:
          claimName: jenkins-pvc
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock
          type: Socket
---
# ServiceAccount para Jenkins
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: cicd
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: jenkins
  namespace: cicd
---
# Registry privado
apiVersion: apps/v1
kind: Deployment
metadata:
  name: docker-registry
  namespace: cicd
spec:
  replicas: 1
  selector:
    matchLabels:
      app: docker-registry
  template:
    metadata:
      labels:
        app: docker-registry
    spec:
      containers:
      - name: registry
        image: registry:2.8
        ports:
        - containerPort: 5000
        env:
        - name: REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY
          value: /var/lib/registry
        - name: REGISTRY_AUTH
          value: "htpasswd"
        - name: REGISTRY_AUTH_HTPASSWD_REALM
          value: "Registry Realm"
        - name: REGISTRY_AUTH_HTPASSWD_PATH
          value: "/auth/htpasswd"
        volumeMounts:
        - name: registry-storage
          mountPath: /var/lib/registry
        - name: registry-auth
          mountPath: /auth
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "300m"
      volumes:
      - name: registry-storage
        persistentVolumeClaim:
          claimName: registry-pvc
      - name: registry-auth
        secret:
          secretName: registry-auth
```

#### Pipeline Configuration

```groovy
// Jenkinsfile para microservicio
pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: docker
    image: docker:20.10-dind
    securityContext:
      privileged: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  - name: kubectl
    image: bitnami/kubectl:latest
    command:
    - sleep
    args:
    - 99d
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
            """
        }
    }
    
    environment {
        REGISTRY = 'docker-registry.cicd.svc.cluster.local:5000'
        APP_NAME = 'user-service'
        NAMESPACE = 'microservices'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Test') {
            steps {
                container('docker') {
                    script {
                        sh """
                        docker build -t ${APP_NAME}-test:${BUILD_NUMBER} -f Dockerfile.test .
                        docker run --rm ${APP_NAME}-test:${BUILD_NUMBER} npm test
                        """
                    }
                }
            }
        }
        
        stage('Build') {
            steps {
                container('docker') {
                    script {
                        sh """
                        docker build -t ${REGISTRY}/${APP_NAME}:${BUILD_NUMBER} .
                        docker tag ${REGISTRY}/${APP_NAME}:${BUILD_NUMBER} ${REGISTRY}/${APP_NAME}:latest
                        """
                    }
                }
            }
        }
        
        stage('Push') {
            steps {
                container('docker') {
                    withCredentials([usernamePassword(credentialsId: 'registry-creds', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
                        sh """
                        echo \$PASSWORD | docker login -u \$USERNAME --password-stdin ${REGISTRY}
                        docker push ${REGISTRY}/${APP_NAME}:${BUILD_NUMBER}
                        docker push ${REGISTRY}/${APP_NAME}:latest
                        """
                    }
                }
            }
        }
        
        stage('Deploy to Staging') {
            steps {
                container('kubectl') {
                    script {
                        sh """
                        # Actualizar deployment con nueva imagen
                        kubectl set image deployment/${APP_NAME} ${APP_NAME}=${REGISTRY}/${APP_NAME}:${BUILD_NUMBER} -n ${NAMESPACE}-staging
                        
                        # Esperar a que el rollout termine
                        kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE}-staging --timeout=300s
                        
                        # Ejecutar tests de integración
                        kubectl run integration-tests-${BUILD_NUMBER} --image=${REGISTRY}/${APP_NAME}-tests:latest --rm -i --restart=Never -n ${NAMESPACE}-staging -- npm run integration-tests
                        """
                    }
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    input message: '¿Desplegar a producción?', ok: 'Deploy'
                }
                container('kubectl') {
                    script {
                        sh """
                        # Aplicar manifiestos de producción
                        envsubst < k8s/production/deployment.yaml | kubectl apply -f -
                        
                        # Esperar rollout
                        kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=600s
                        
                        # Verificar health checks
                        kubectl wait --for=condition=ready pod -l app=${APP_NAME} -n ${NAMESPACE} --timeout=300s
                        """
                    }
                }
            }
        }
    }
    
    post {
        always {
            container('docker') {
                sh """
                docker system prune -f
                """
            }
        }
        success {
            slackSend channel: '#deployments', 
                     color: 'good', 
                     message: "✅ ${APP_NAME} v${BUILD_NUMBER} desplegado exitosamente"
        }
        failure {
            slackSend channel: '#deployments', 
                     color: 'danger', 
                     message: "❌ Fallo en el despliegue de ${APP_NAME} v${BUILD_NUMBER}"
        }
    }
}
```

---

## Desarrollo Local

### Caso de Uso: Entorno de Desarrollo Local con Hot Reload

**Escenario**: Desarrolladores que necesitan un entorno local que simule producción pero con capacidades de desarrollo rápido.

#### Configuración con Skaffold

```yaml
# skaffold.yaml
apiVersion: skaffold/v4beta6
kind: Config
metadata:
  name: microservices-dev
build:
  artifacts:
  - image: user-service
    context: services/user-service
    docker:
      dockerfile: Dockerfile.dev
    sync:
      manual:
      - src: "src/**/*.js"
        dest: /app/src
  - image: order-service
    context: services/order-service
    docker:
      dockerfile: Dockerfile.dev
    sync:
      manual:
      - src: "src/**/*.js"
        dest: /app/src
  - image: frontend
    context: frontend
    docker:
      dockerfile: Dockerfile.dev
    sync:
      manual:
      - src: "src/**/*.{js,jsx,css}"
        dest: /app/src
  local:
    push: false
    useDockerCLI: true

deploy:
  kubectl:
    manifests:
    - k8s/development/*.yaml

portForward:
- resourceType: service
  resourceName: frontend
  namespace: development
  port: 3000
  localPort: 3000
- resourceType: service
  resourceName: user-service
  namespace: development
  port: 8080
  localPort: 8081
- resourceType: service
  resourceName: order-service
  namespace: development
  port: 8080
  localPort: 8082

profiles:
- name: debug
  build:
    artifacts:
    - image: user-service
      docker:
        dockerfile: Dockerfile.debug
    - image: order-service
      docker:
        dockerfile: Dockerfile.debug
  deploy:
    kubectl:
      manifests:
      - k8s/development/*.yaml
      - k8s/development/debug/*.yaml
```

#### Manifiestos de Desarrollo

```yaml
# k8s/development/microservices.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
      - name: user-service
        image: user-service
        ports:
        - containerPort: 8080
        env:
        - name: NODE_ENV
          value: "development"
        - name: DB_HOST
          value: "postgres.development.svc.cluster.local"
        - name: REDIS_HOST
          value: "redis.development.svc.cluster.local"
        - name: DEBUG
          value: "app:*"
        volumeMounts:
        - name: app-source
          mountPath: /app/src
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: app-source
        emptyDir: {}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      containers:
      - name: order-service
        image: order-service
        ports:
        - containerPort: 8080
        env:
        - name: NODE_ENV
          value: "development"
        - name: USER_SERVICE_URL
          value: "http://user-service.development.svc.cluster.local:8080"
        - name: DB_HOST
          value: "postgres.development.svc.cluster.local"
        - name: DEBUG
          value: "app:*"
        volumeMounts:
        - name: app-source
          mountPath: /app/src
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: app-source
        emptyDir: {}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: frontend
        ports:
        - containerPort: 3000
        env:
        - name: REACT_APP_API_URL
          value: "http://localhost:8081"
        - name: CHOKIDAR_USEPOLLING
          value: "true"
        - name: FAST_REFRESH
          value: "true"
        volumeMounts:
        - name: app-source
          mountPath: /app/src
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
      volumes:
      - name: app-source
        emptyDir: {}
```

#### Dockerfile para Desarrollo

```dockerfile
# services/user-service/Dockerfile.dev
FROM node:18-alpine

WORKDIR /app

# Instalar nodemon para hot reload
RUN npm install -g nodemon

# Copiar package files
COPY package*.json ./
RUN npm install

# Copiar código fuente
COPY src/ ./src/

# Exponer puerto
EXPOSE 8080

# Comando de desarrollo con hot reload
CMD ["nodemon", "--watch", "src", "--ext", "js,json", "src/index.js"]
```

```dockerfile
# services/user-service/Dockerfile.debug
FROM node:18-alpine

WORKDIR /app

# Instalar herramientas de debug
RUN npm install -g nodemon node-inspector

COPY package*.json ./
RUN npm install

COPY src/ ./src/

EXPOSE 8080 9229

# Comando con debug habilitado
CMD ["nodemon", "--inspect=0.0.0.0:9229", "--watch", "src", "src/index.js"]
```

---

## Retail y Punto de Venta

### Caso de Uso: Sistema POS Distribuido

**Escenario**: Cadena de tiendas retail que necesita sistemas POS que funcionen offline y sincronicen cuando hay conectividad.

#### Arquitectura POS Edge

```yaml
# pos-system.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: retail-pos
---
# Aplicación POS principal
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pos-app
  namespace: retail-pos
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pos-app
  template:
    metadata:
      labels:
        app: pos-app
    spec:
      nodeSelector:
        retail.com/location: store
      containers:
      - name: pos-app
        image: retail/pos-app:v3.2
        ports:
        - containerPort: 8080
        env:
        - name: STORE_ID
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: DB_HOST
          value: "sqlite:///data/pos.db"
        - name: SYNC_ENDPOINT
          value: "https://api.retail.com/sync"
        - name: OFFLINE_MODE
          value: "true"
        volumeMounts:
        - name: pos-data
          mountPath: /data
        - name: receipt-printer
          mountPath: /dev/usb/lp0
        - name: barcode-scanner
          mountPath: /dev/ttyUSB0
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        securityContext:
          privileged: true  # Para acceso a dispositivos USB
      - name: sync-agent
        image: retail/sync-agent:v2.1
        env:
        - name: STORE_ID
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: LOCAL_DB
          value: "sqlite:///data/pos.db"
        - name: CENTRAL_API
          value: "https://api.retail.com"
        - name: SYNC_INTERVAL
          value: "300"  # 5 minutos
        volumeMounts:
        - name: pos-data
          mountPath: /data
        resources:
          requests:
            memory: "128Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "100m"
      volumes:
      - name: pos-data
        hostPath:
          path: /opt/retail/data
          type: DirectoryOrCreate
      - name: receipt-printer
        hostPath:
          path: /dev/usb/lp0
          type: CharDevice
      - name: barcode-scanner
        hostPath:
          path: /dev/ttyUSB0
          type: CharDevice
---
# Sistema de inventario local
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory-service
  namespace: retail-pos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: inventory-service
  template:
    metadata:
      labels:
        app: inventory-service
    spec:
      containers:
      - name: inventory
        image: retail/inventory:v2.0
        ports:
        - containerPort: 8081
        env:
        - name: STORE_ID
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: DB_HOST
          value: "sqlite:///data/inventory.db"
        volumeMounts:
        - name: inventory-data
          mountPath: /data
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "300m"
      volumes:
      - name: inventory-data
        hostPath:
          path: /opt/retail/inventory
          type: DirectoryOrCreate
---
# Base de datos local para backup
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: local-postgres
  namespace: retail-pos
spec:
  serviceName: local-postgres
  replicas: 1
  selector:
    matchLabels:
      app: local-postgres
  template:
    metadata:
      labels:
        app: local-postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "retail_backup"
        - name: POSTGRES_USER
          value: "retail"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: local-path
      resources:
        requests:
          storage: 5Gi
```

#### Configuración de Sincronización

```yaml
# sync-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: data-sync
  namespace: retail-pos
spec:
  schedule: "*/5 * * * *"  # Cada 5 minutos
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: sync
            image: retail/sync-job:v1.3
            env:
            - name: STORE_ID
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: LOCAL_DB
              value: "sqlite:///data/pos.db"
            - name: BACKUP_DB
              value: "postgresql://retail:password@local-postgres:5432/retail_backup"
            - name: CENTRAL_API
              value: "https://api.retail.com"
            - name: MAX_RETRY_ATTEMPTS
              value: "3"
            volumeMounts:
            - name: pos-data
              mountPath: /data
            command:
            - /bin/sh
            - -c
            - |
              #!/bin/sh
              echo "🔄 Iniciando sincronización para store: $STORE_ID"
              
              # Verificar conectividad a internet
              if ! wget -q --spider https://api.retail.com/health; then
                echo "⚠️ Sin conectividad - guardando en backup local"
                /app/backup-local.sh
                exit 0
              fi
              
              echo "✅ Conectividad OK - sincronizando con central"
              
              # Sincronizar ventas
              /app/sync-sales.sh
              
              # Sincronizar inventario
              /app/sync-inventory.sh
              
              # Obtener actualizaciones de productos
              /app/fetch-product-updates.sh
              
              # Obtener configuraciones de precios
              /app/fetch-pricing-updates.sh
              
              echo "✅ Sincronización completada"
          volumes:
          - name: pos-data
            hostPath:
              path: /opt/retail/data
          restartPolicy: OnFailure
```

#### Monitoreo de Tienda

```yaml
# store-monitoring.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: store-monitor
  namespace: retail-pos
spec:
  selector:
    matchLabels:
      app: store-monitor
  template:
    metadata:
      labels:
        app: store-monitor
    spec:
      hostNetwork: true
      containers:
      - name: monitor
        image: retail/store-monitor:v1.1
        env:
        - name: STORE_ID
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: METRICS_ENDPOINT
          value: "http://prometheus.monitoring.svc.cluster.local:9090"
        ports:
        - containerPort: 9100
          hostPort: 9100
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: pos-logs
          mountPath: /var/log/pos
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      - name: pos-logs
        hostPath:
          path: /opt/retail/logs
```

Este documento proporciona casos de uso detallados y prácticos para k3s, desde edge computing hasta sistemas IoT, home labs, CI/CD, desarrollo local y aplicaciones retail. Cada caso incluye configuraciones YAML completas, scripts de deployment y consideraciones específicas para el entorno de uso.
