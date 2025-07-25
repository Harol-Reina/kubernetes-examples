# Configuración de Entorno de Producción en Kubernetes

Esta guía proporciona las mejores prácticas y configuraciones necesarias para desplegar aplicaciones en entornos de producción robustos, seguros y escalables en Kubernetes.

## Tabla de Contenidos

1. [Introducción](#introducción)
2. [Prerequisitos](#prerequisitos)
3. [Arquitectura de Producción](#arquitectura-de-producción)
4. [Configuración de Seguridad](#configuración-de-seguridad)
5. [Alta Disponibilidad](#alta-disponibilidad)
6. [Monitoreo y Observabilidad](#monitoreo-y-observabilidad)
7. [Backup y Recuperación](#backup-y-recuperación)
8. [Escalabilidad](#escalabilidad)
9. [Networking en Producción](#networking-en-producción)
10. [Storage Persistente](#storage-persistente)
11. [Gestión de Secretos](#gestión-de-secretos)
12. [CI/CD para Producción](#cicd-para-producción)
13. [Disaster Recovery](#disaster-recovery)
14. [Compliance y Auditoría](#compliance-y-auditoría)
15. [Troubleshooting](#troubleshooting)

---

## Introducción

Un entorno de producción en Kubernetes requiere consideraciones especiales para garantizar:

- **Disponibilidad**: 99.9%+ uptime
- **Seguridad**: Protección contra amenazas
- **Escalabilidad**: Manejo de carga variable
- **Observabilidad**: Monitoreo completo
- **Recuperación**: Backup y disaster recovery
- **Compliance**: Cumplimiento normativo

### Principios de Producción

1. **Defense in Depth**: Múltiples capas de seguridad
2. **Immutable Infrastructure**: Infraestructura inmutable
3. **Everything as Code**: Configuración versionada
4. **Fail Fast, Recover Faster**: Detección y recuperación rápida
5. **Zero Trust**: No confiar en ningún componente por defecto

---

## Prerequisitos

### Infraestructura Base

#### 1. Cluster Multi-Master
```yaml
# kubeadm-config.yaml para HA
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.28.4
controlPlaneEndpoint: "k8s-api.company.com:6443"
apiServer:
  certSANs:
  - "k8s-api.company.com"
  - "10.0.0.100"
  - "10.0.0.101"
  - "10.0.0.102"
etcd:
  external:
    endpoints:
    - "https://etcd1.company.com:2379"
    - "https://etcd2.company.com:2379"
    - "https://etcd3.company.com:2379"
networking:
  serviceSubnet: "10.96.0.0/12"
  podSubnet: "10.244.0.0/16"
```

#### 2. Hardware Mínimo por Nodo
```bash
# Master Nodes (mínimo 3)
CPU: 4 cores
RAM: 8GB
Storage: 100GB SSD
Network: 1Gbps

# Worker Nodes (mínimo 3)
CPU: 8 cores
RAM: 16GB
Storage: 200GB SSD
Network: 1Gbps

# ETCD Nodes (separados, mínimo 3)
CPU: 2 cores
RAM: 8GB
Storage: 50GB SSD (alta IOPS)
Network: 1Gbps
```

### Herramientas Requeridas

#### 1. Gestión de Cluster
```bash
# Kubernetes tools
kubectl v1.28+
kubeadm v1.28+
kubelet v1.28+

# CNI Plugin
Calico/Cilium/Weave Net

# Container Runtime
containerd 1.7+
```

#### 2. Observabilidad
```bash
# Monitoring Stack
Prometheus + Grafana
AlertManager
Jaeger/Zipkin (tracing)

# Logging Stack
ELK/EFK Stack
Fluentd/Fluent Bit

# APM
New Relic/DataDog/Dynatrace
```

#### 3. Seguridad
```bash
# Security Tools
Falco (runtime security)
OPA Gatekeeper (policy enforcement)
Trivy (vulnerability scanning)
Cert-Manager (certificate management)
```

---

## Arquitectura de Producción

### 1. Topología Multi-Zona

```yaml
# zona-topology.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-topology
data:
  zones: |
    us-east-1a: control-plane, workers
    us-east-1b: control-plane, workers
    us-east-1c: control-plane, workers
  
  node-distribution: |
    control-plane: 3 nodes (1 per zone)
    workers: 9 nodes (3 per zone)
    etcd: 3 nodes (1 per zone, dedicated)
```

### 2. Namespace Strategy

```yaml
# production-namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: production
    compliance: required
    monitoring: enabled
---
apiVersion: v1
kind: Namespace
metadata:
  name: production-db
  labels:
    environment: production
    data-classification: sensitive
    backup: required
---
apiVersion: v1
kind: Namespace
metadata:
  name: production-cache
  labels:
    environment: production
    data-classification: temporary
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    purpose: observability
    critical: true
---
apiVersion: v1
kind: Namespace
metadata:
  name: security
  labels:
    purpose: security
    critical: true
```

### 3. Resource Quotas para Producción

```yaml
# production-quotas.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "50"
    requests.memory: 100Gi
    limits.cpu: "100"
    limits.memory: 200Gi
    persistentvolumeclaims: "50"
    services: "30"
    secrets: "50"
    configmaps: "50"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limits
  namespace: production
spec:
  limits:
  - default:
      cpu: "2"
      memory: "4Gi"
    defaultRequest:
      cpu: "500m"
      memory: "1Gi"
    max:
      cpu: "8"
      memory: "16Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
    type: Container
```

---

## Configuración de Seguridad

### 1. RBAC (Role-Based Access Control)

```yaml
# production-rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: production-operator
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: production-deployer
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: production-deployer-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: production-deployer
  namespace: production
roleRef:
  kind: Role
  name: production-deployer
  apiGroup: rbac.authorization.k8s.io
```

### 2. Pod Security Standards

```yaml
# pod-security-policy.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: production-security-policy
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: require-non-root
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - production
    validate:
      message: "Containers must run as non-root user"
      pattern:
        spec:
          securityContext:
            runAsNonRoot: true
  - name: require-readonly-rootfs
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - production
    validate:
      message: "Root filesystem must be read-only"
      pattern:
        spec:
          containers:
          - securityContext:
              readOnlyRootFilesystem: true
```

### 3. Network Policies

```yaml
# production-network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 5432
```

---

## Alta Disponibilidad

### 1. Deployment con HA

```yaml
# ha-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: production-app
  namespace: production
spec:
  replicas: 6  # Mínimo 2 por zona
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 1
  selector:
    matchLabels:
      app: production-app
  template:
    metadata:
      labels:
        app: production-app
        version: v1.0.0
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - production-app
            topologyKey: "kubernetes.io/hostname"
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAntiAffinity:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - production-app
              topologyKey: "topology.kubernetes.io/zone"
      containers:
      - name: app
        image: myapp:1.0.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        startupProbe:
          httpGet:
            path: /startup
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 1
          failureThreshold: 30
        securityContext:
          runAsNonRoot: true
          runAsUser: 1001
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
```

### 2. Database HA con PostgreSQL

```yaml
# postgresql-ha.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgresql-cluster
  namespace: production-db
spec:
  instances: 3
  
  postgresql:
    parameters:
      max_connections: "200"
      shared_buffers: "256MB"
      effective_cache_size: "1GB"
      wal_buffers: "16MB"
      checkpoint_completion_target: "0.9"
      random_page_cost: "1.1"
      
  bootstrap:
    initdb:
      database: app_db
      owner: app_user
      secret:
        name: postgresql-credentials
        
  storage:
    size: 100Gi
    storageClass: fast-ssd
    
  monitoring:
    enabled: true
    
  backup:
    retentionPolicy: "30d"
    barmanObjectStore:
      destinationPath: "s3://backups/postgresql"
      s3Credentials:
        accessKeyId:
          name: backup-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: backup-credentials
          key: SECRET_ACCESS_KEY
      wal:
        retention: "5d"
      data:
        retention: "30d"
```

### 3. Redis HA con Sentinel

```yaml
# redis-ha.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-master
  namespace: production-cache
spec:
  serviceName: redis-master
  replicas: 1
  selector:
    matchLabels:
      app: redis
      role: master
  template:
    metadata:
      labels:
        app: redis
        role: master
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        volumeMounts:
        - name: redis-data
          mountPath: /data
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1"
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 20Gi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-replica
  namespace: production-cache
spec:
  serviceName: redis-replica
  replicas: 2
  selector:
    matchLabels:
      app: redis
      role: replica
  template:
    metadata:
      labels:
        app: redis
        role: replica
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        command:
        - redis-server
        - --replicaof
        - redis-master
        - "6379"
        ports:
        - containerPort: 6379
        volumeMounts:
        - name: redis-data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 20Gi
```

---

## Monitoreo y Observabilidad

### 1. Prometheus Stack

```yaml
# prometheus-production.yaml
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: production
  namespace: monitoring
spec:
  serviceAccountName: prometheus
  serviceMonitorSelector:
    matchLabels:
      team: production
  ruleSelector:
    matchLabels:
      team: production
  resources:
    requests:
      memory: 2Gi
      cpu: 1
    limits:
      memory: 4Gi
      cpu: 2
  retention: 30d
  storage:
    volumeClaimTemplate:
      spec:
        storageClassName: fast-ssd
        resources:
          requests:
            storage: 100Gi
  alerting:
    alertmanagers:
    - namespace: monitoring
      name: alertmanager-main
      port: web
  additionalScrapeConfigs:
    name: additional-scrape-configs
    key: prometheus-additional.yaml
```

### 2. Grafana Dashboards

```yaml
# grafana-production.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 2
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
              name: grafana-credentials
              key: admin-password
        - name: GF_DATABASE_TYPE
          value: postgres
        - name: GF_DATABASE_HOST
          value: postgresql-cluster-rw:5432
        - name: GF_DATABASE_NAME
          value: grafana
        - name: GF_DATABASE_USER
          valueFrom:
            secretKeyRef:
              name: grafana-db-credentials
              key: username
        - name: GF_DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-db-credentials
              key: password
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
      volumes:
      - name: grafana-storage
        persistentVolumeClaim:
          claimName: grafana-pvc
```

### 3. Alerting Rules

```yaml
# production-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: production-alerts
  namespace: monitoring
  labels:
    team: production
spec:
  groups:
  - name: production.rules
    rules:
    - alert: HighErrorRate
      expr: |
        (
          rate(http_requests_total{job="production-app",code=~"5.."}[5m])
          /
          rate(http_requests_total{job="production-app"}[5m])
        ) > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value | humanizePercentage }} for the last 5 minutes"
        
    - alert: HighMemoryUsage
      expr: |
        (
          container_memory_working_set_bytes{namespace="production"}
          /
          container_spec_memory_limit_bytes{namespace="production"}
        ) > 0.9
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage detected"
        description: "Memory usage is {{ $value | humanizePercentage }} on {{ $labels.pod }}"
        
    - alert: PodCrashLooping
      expr: |
        rate(kube_pod_container_status_restarts_total{namespace="production"}[15m]) * 60 * 15 > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Pod is crash looping"
        description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is crash looping"
```

---

## Backup y Recuperación

### 1. Velero Backup Strategy

```yaml
# backup-schedule.yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: production-daily
  namespace: velero
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  template:
    includedNamespaces:
    - production
    - production-db
    - production-cache
    excludedResources:
    - events
    - events.events.k8s.io
    storageLocation: default
    volumeSnapshotLocations:
    - default
    ttl: 720h  # 30 days
---
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: production-weekly
  namespace: velero
spec:
  schedule: "0 1 * * 0"  # Weekly on Sunday at 1 AM
  template:
    includedNamespaces:
    - production
    - production-db
    - production-cache
    - monitoring
    - security
    storageLocation: default
    volumeSnapshotLocations:
    - default
    ttl: 2160h  # 90 days
```

### 2. Database Backup

```yaml
# postgres-backup.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: production-db
spec:
  schedule: "0 3 * * *"  # Daily at 3 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: postgres-backup
            image: postgres:15-alpine
            command:
            - /bin/bash
            - -c
            - |
              PGPASSWORD=$POSTGRES_PASSWORD pg_dump \
                -h postgresql-cluster-rw \
                -U $POSTGRES_USER \
                -d $POSTGRES_DB \
                --verbose \
                --no-owner \
                --no-privileges \
                | gzip > /backup/backup-$(date +%Y%m%d-%H%M%S).sql.gz
              
              # Upload to S3
              aws s3 cp /backup/backup-$(date +%Y%m%d-%H%M%S).sql.gz \
                s3://company-backups/postgresql/
              
              # Cleanup old local backups
              find /backup -name "*.sql.gz" -mtime +7 -delete
            env:
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: postgresql-credentials
                  key: username
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgresql-credentials
                  key: password
            - name: POSTGRES_DB
              value: "app_db"
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
          restartPolicy: OnFailure
```

---

## Escalabilidad

### 1. Horizontal Pod Autoscaler

```yaml
# hpa-production.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: production-app-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: production-app
  minReplicas: 6
  maxReplicas: 50
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "100"
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
      - type: Pods
        value: 4
        periodSeconds: 60
      selectPolicy: Max
```

### 2. Vertical Pod Autoscaler

```yaml
# vpa-production.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: production-app-vpa
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: production-app
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: app
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 4
        memory: 8Gi
      controlledResources: ["cpu", "memory"]
```

### 3. Cluster Autoscaler

```yaml
# cluster-autoscaler.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.27.3
        name: cluster-autoscaler
        resources:
          limits:
            cpu: 100m
            memory: 300Mi
          requests:
            cpu: 100m
            memory: 300Mi
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/production
        - --balance-similar-node-groups
        - --scale-down-enabled=true
        - --scale-down-delay-after-add=10m
        - --scale-down-unneeded-time=10m
        - --scale-down-utilization-threshold=0.5
        env:
        - name: AWS_REGION
          value: us-east-1
```

---

## Configuraciones Adicionales

### 1. Ingress con SSL/TLS

```yaml
# production-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: production-ingress
  namespace: production
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
spec:
  tls:
  - hosts:
    - api.company.com
    secretName: production-tls
  rules:
  - host: api.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: production-app-service
            port:
              number: 80
```

### 2. Istio Service Mesh

```yaml
# istio-production.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: production-app
  namespace: production
spec:
  hosts:
  - api.company.com
  gateways:
  - production-gateway
  http:
  - match:
    - uri:
        prefix: /api/v1
    route:
    - destination:
        host: production-app-service
        port:
          number: 80
    timeout: 30s
    retries:
      attempts: 3
      perTryTimeout: 10s
```

Esta configuración de producción proporciona una base sólida para aplicaciones críticas en Kubernetes, con énfasis en seguridad, disponibilidad y observabilidad.
