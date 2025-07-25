# Casos de Uso de Producción en Kubernetes

Esta documentación presenta casos de uso prácticos para implementar aplicaciones en entornos de producción en Kubernetes, cubriendo desde despliegues básicos hasta arquitecturas complejas de alta disponibilidad.

## Tabla de Contenidos

1. [Aplicación Web de Alto Tráfico](#1-aplicación-web-de-alto-tráfico)
2. [Microservicios con Service Mesh](#2-microservicios-con-service-mesh)
3. [Base de Datos HA con Replicación](#3-base-de-datos-ha-con-replicación)
4. [Cache Distribuido con Redis Cluster](#4-cache-distribuido-con-redis-cluster)
5. [API Gateway con Rate Limiting](#5-api-gateway-con-rate-limiting)
6. [Aplicación con Jobs y CronJobs](#6-aplicación-con-jobs-y-cronjobs)
7. [Machine Learning Pipeline](#7-machine-learning-pipeline)
8. [Sistema de Cola de Mensajes](#8-sistema-de-cola-de-mensajes)
9. [Aplicación Multi-tenant](#9-aplicación-multi-tenant)
10. [Sistema de Logs Distribuidos](#10-sistema-de-logs-distribuidos)

---

## 1. Aplicación Web de Alto Tráfico

### Objetivo
Desplegar una aplicación web que pueda manejar millones de requests por día con alta disponibilidad.

### Arquitectura
```
Internet → CloudFlare → Load Balancer → Kubernetes Ingress → Pods (20+)
                                                          → Cache Layer (Redis)
                                                          → Database Cluster (PostgreSQL)
```

### Configuración

#### 1. Frontend Deployment
```yaml
# frontend-production.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-app
  namespace: production
spec:
  replicas: 15
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 5
      maxUnavailable: 2
  selector:
    matchLabels:
      app: frontend
      tier: web
  template:
    metadata:
      labels:
        app: frontend
        tier: web
        version: v2.1.0
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAntiAffinity:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - frontend
              topologyKey: kubernetes.io/hostname
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-type
                operator: In
                values:
                - web-tier
      containers:
      - name: frontend
        image: company/frontend:2.1.0
        ports:
        - containerPort: 3000
          name: http
        env:
        - name: NODE_ENV
          value: "production"
        - name: API_BASE_URL
          value: "https://api.company.com"
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: redis-credentials
              key: url
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /healthz
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        startupProbe:
          httpGet:
            path: /startup
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 1
          failureThreshold: 30
        securityContext:
          runAsNonRoot: true
          runAsUser: 1001
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/.next/cache
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: frontend
```

#### 2. HPA con Métricas Personalizadas
```yaml
# frontend-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: frontend-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend-app
  minReplicas: 15
  maxReplicas: 100
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
        averageValue: "50"
  - type: External
    external:
      metric:
        name: cloudflare_requests_per_minute
      target:
        type: AverageValue
        averageValue: "1000"
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 600  # 10 minutos
      policies:
      - type: Percent
        value: 10
        periodSeconds: 300
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
      - type: Pods
        value: 10
        periodSeconds: 60
      selectPolicy: Max
```

#### 3. Ingress con Rate Limiting
```yaml
# frontend-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress
  namespace: production
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rate-limit: "1000"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    nginx.ingress.kubernetes.io/rate-limit-connections: "100"
    nginx.ingress.kubernetes.io/upstream-keepalive-connections: "100"
    nginx.ingress.kubernetes.io/upstream-keepalive-requests: "10000"
    nginx.ingress.kubernetes.io/proxy-buffering: "on"
    nginx.ingress.kubernetes.io/proxy-buffer-size: "8k"
spec:
  tls:
  - hosts:
    - www.company.com
    - company.com
    secretName: frontend-tls
  rules:
  - host: www.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
  - host: company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
```

---

## 2. Microservicios con Service Mesh

### Objetivo
Implementar una arquitectura de microservicios con comunicación segura, observabilidad y traffic management usando Istio.

### Arquitectura
```
Istio Gateway → Virtual Services → Microservices (Auth, User, Order, Payment, Notification)
                                → Shared Services (Database, Cache, Message Queue)
```

### Configuración

#### 1. Istio Gateway
```yaml
# istio-gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: microservices-gateway
  namespace: production
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: api-tls-secret
    hosts:
    - api.company.com
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - api.company.com
    tls:
      httpsRedirect: true
```

#### 2. Auth Service
```yaml
# auth-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-service
  namespace: production
spec:
  replicas: 5
  selector:
    matchLabels:
      app: auth-service
      version: v1
  template:
    metadata:
      labels:
        app: auth-service
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
    spec:
      containers:
      - name: auth-service
        image: company/auth-service:1.2.0
        ports:
        - containerPort: 8080
        - containerPort: 9090  # Metrics
        env:
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: auth-secrets
              key: jwt-secret
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: auth-db-credentials
              key: url
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "400m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: auth-service
  namespace: production
  labels:
    app: auth-service
spec:
  ports:
  - port: 8080
    targetPort: 8080
    name: http
  - port: 9090
    targetPort: 9090
    name: metrics
  selector:
    app: auth-service
```

#### 3. Virtual Service con Circuit Breaker
```yaml
# auth-virtualservice.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: auth-service
  namespace: production
spec:
  hosts:
  - api.company.com
  gateways:
  - microservices-gateway
  http:
  - match:
    - uri:
        prefix: /auth/
    route:
    - destination:
        host: auth-service
        port:
          number: 8080
    timeout: 10s
    retries:
      attempts: 3
      perTryTimeout: 3s
      retryOn: 5xx,reset,connect-failure,refused-stream
    fault:
      delay:
        percentage:
          value: 0.1
        fixedDelay: 5s
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: auth-service
  namespace: production
spec:
  host: auth-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 50
      http:
        http1MaxPendingRequests: 100
        maxRequestsPerConnection: 10
    circuitBreaker:
      consecutiveErrors: 3
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
    loadBalancer:
      simple: LEAST_CONN
```

#### 4. Service Monitor para Prometheus
```yaml
# auth-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: auth-service
  namespace: production
  labels:
    app: auth-service
spec:
  selector:
    matchLabels:
      app: auth-service
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

---

## 3. Base de Datos HA con Replicación

### Objetivo
Configurar PostgreSQL con alta disponibilidad, replicación automática y backup automatizado.

### Configuración

#### 1. PostgreSQL Cluster con CloudNativePG
```yaml
# postgresql-cluster.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-cluster
  namespace: production-db
spec:
  instances: 3
  
  postgresql:
    parameters:
      # Performance tuning
      max_connections: "300"
      shared_buffers: "1GB"
      effective_cache_size: "3GB"
      maintenance_work_mem: "256MB"
      checkpoint_completion_target: "0.9"
      wal_buffers: "16MB"
      default_statistics_target: "100"
      random_page_cost: "1.1"
      effective_io_concurrency: "200"
      work_mem: "4MB"
      min_wal_size: "1GB"
      max_wal_size: "4GB"
      
      # Replication settings
      max_wal_senders: "10"
      wal_keep_segments: "100"
      hot_standby: "on"
      
      # Security
      ssl: "on"
      ssl_cert_file: "/etc/ssl/certs/server.crt"
      ssl_key_file: "/etc/ssl/private/server.key"
      
  primaryUpdateStrategy: unsupervised
  
  bootstrap:
    initdb:
      database: production_db
      owner: app_user
      secret:
        name: postgres-credentials
      postInitSQL:
      - CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
      - CREATE EXTENSION IF NOT EXISTS pg_trgm;
      - CREATE EXTENSION IF NOT EXISTS btree_gin;
      
  storage:
    size: 500Gi
    storageClass: fast-ssd
    
  resources:
    requests:
      memory: "2Gi"
      cpu: "1"
    limits:
      memory: "4Gi"
      cpu: "2"
      
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            cnpg.io/cluster: postgres-cluster
        topologyKey: kubernetes.io/hostname
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node-type
            operator: In
            values:
            - database
            
  monitoring:
    enabled: true
    
  backup:
    retentionPolicy: "30d"
    barmanObjectStore:
      destinationPath: "s3://company-backups/postgresql"
      s3Credentials:
        accessKeyId:
          name: backup-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: backup-credentials
          key: SECRET_ACCESS_KEY
        region:
          name: backup-credentials
          key: REGION
      wal:
        retention: "7d"
        maxParallel: 2
      data:
        retention: "30d"
        jobs: 2
```

#### 2. Connection Pooler
```yaml
# pgbouncer.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pgbouncer
  namespace: production-db
spec:
  replicas: 3
  selector:
    matchLabels:
      app: pgbouncer
  template:
    metadata:
      labels:
        app: pgbouncer
    spec:
      containers:
      - name: pgbouncer
        image: pgbouncer/pgbouncer:latest
        ports:
        - containerPort: 5432
        env:
        - name: DATABASES_HOST
          value: "postgres-cluster-rw"
        - name: DATABASES_PORT
          value: "5432"
        - name: DATABASES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: username
        - name: DATABASES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: password
        - name: DATABASES_DBNAME
          value: "production_db"
        - name: POOL_MODE
          value: "transaction"
        - name: MAX_CLIENT_CONN
          value: "1000"
        - name: DEFAULT_POOL_SIZE
          value: "25"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          tcpSocket:
            port: 5432
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          tcpSocket:
            port: 5432
          initialDelaySeconds: 5
          periodSeconds: 5
```

---

## 4. Cache Distribuido con Redis Cluster

### Objetivo
Configurar Redis Cluster para alta disponibilidad y distribución automática de datos.

### Configuración

#### 1. Redis Cluster
```yaml
# redis-cluster.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-cluster
  namespace: production-cache
spec:
  serviceName: redis-cluster
  replicas: 6  # 3 masters + 3 replicas
  selector:
    matchLabels:
      app: redis-cluster
  template:
    metadata:
      labels:
        app: redis-cluster
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: redis-cluster
            topologyKey: kubernetes.io/hostname
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        - containerPort: 16379  # Cluster bus
        command:
        - redis-server
        args:
        - /etc/redis/redis.conf
        - --cluster-enabled
        - "yes"
        - --cluster-config-file
        - /data/nodes.conf
        - --cluster-node-timeout
        - "5000"
        - --appendonly
        - "yes"
        - --save
        - "900 1"
        - --save
        - "300 10"
        - --save
        - "60 10000"
        - --maxmemory
        - "1gb"
        - --maxmemory-policy
        - "allkeys-lru"
        volumeMounts:
        - name: redis-data
          mountPath: /data
        - name: redis-config
          mountPath: /etc/redis
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: redis-config
        configMap:
          name: redis-config
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

#### 2. Redis Cluster Initialization Job
```yaml
# redis-cluster-init.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: redis-cluster-init
  namespace: production-cache
spec:
  template:
    spec:
      containers:
      - name: redis-cluster-init
        image: redis:7-alpine
        command:
        - /bin/sh
        - -c
        - |
          echo "Waiting for Redis nodes to be ready..."
          for i in {0..5}; do
            until redis-cli -h redis-cluster-$i.redis-cluster ping; do
              echo "Waiting for redis-cluster-$i..."
              sleep 2
            done
          done
          
          echo "Creating Redis cluster..."
          redis-cli --cluster create \
            redis-cluster-0.redis-cluster:6379 \
            redis-cluster-1.redis-cluster:6379 \
            redis-cluster-2.redis-cluster:6379 \
            redis-cluster-3.redis-cluster:6379 \
            redis-cluster-4.redis-cluster:6379 \
            redis-cluster-5.redis-cluster:6379 \
            --cluster-replicas 1 \
            --cluster-yes
            
          echo "Redis cluster created successfully"
      restartPolicy: OnFailure
  backoffLimit: 3
```

---

## 5. API Gateway con Rate Limiting

### Objetivo
Implementar un API Gateway que gestione el tráfico hacia múltiples servicios con rate limiting, autenticación y monitoreo.

### Configuración

#### 1. Kong API Gateway
```yaml
# kong-gateway.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kong-gateway
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: kong-gateway
  template:
    metadata:
      labels:
        app: kong-gateway
    spec:
      containers:
      - name: kong
        image: kong:3.4
        env:
        - name: KONG_DATABASE
          value: "postgres"
        - name: KONG_PG_HOST
          value: "postgres-cluster-rw.production-db"
        - name: KONG_PG_PORT
          value: "5432"
        - name: KONG_PG_DATABASE
          value: "kong"
        - name: KONG_PG_USER
          valueFrom:
            secretKeyRef:
              name: kong-db-credentials
              key: username
        - name: KONG_PG_PASSWORD
          valueFrom:
            secretKeyRef:
              name: kong-db-credentials
              key: password
        - name: KONG_PROXY_ACCESS_LOG
          value: "/dev/stdout"
        - name: KONG_ADMIN_ACCESS_LOG
          value: "/dev/stdout"
        - name: KONG_PROXY_ERROR_LOG
          value: "/dev/stderr"
        - name: KONG_ADMIN_ERROR_LOG
          value: "/dev/stderr"
        - name: KONG_ADMIN_LISTEN
          value: "0.0.0.0:8001"
        - name: KONG_PROXY_LISTEN
          value: "0.0.0.0:8000"
        - name: KONG_PLUGINS
          value: "bundled,rate-limiting,cors,jwt,prometheus"
        ports:
        - containerPort: 8000  # Proxy
        - containerPort: 8001  # Admin API
        - containerPort: 8444  # Proxy SSL
        - containerPort: 8445  # Admin API SSL
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /status
            port: 8001
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /status
            port: 8001
          initialDelaySeconds: 5
          periodSeconds: 5
```

#### 2. Kong Services Configuration
```yaml
# kong-services.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kong-services
  namespace: production
data:
  services.yaml: |
    _format_version: "3.0"
    services:
    - name: auth-service
      url: http://auth-service.production:8080
      plugins:
      - name: rate-limiting
        config:
          minute: 1000
          hour: 10000
          policy: redis
          redis_host: redis-cluster-0.production-cache
          redis_port: 6379
      - name: prometheus
        config:
          per_consumer: true
      routes:
      - name: auth-routes
        paths:
        - /auth
        strip_path: true
        
    - name: user-service
      url: http://user-service.production:8080
      plugins:
      - name: jwt
        config:
          secret_is_base64: false
      - name: rate-limiting
        config:
          minute: 500
          hour: 5000
          policy: redis
          redis_host: redis-cluster-0.production-cache
          redis_port: 6379
      routes:
      - name: user-routes
        paths:
        - /users
        strip_path: true
        
    - name: order-service
      url: http://order-service.production:8080
      plugins:
      - name: jwt
        config:
          secret_is_base64: false
      - name: rate-limiting
        config:
          minute: 200
          hour: 2000
          policy: redis
          redis_host: redis-cluster-0.production-cache
          redis_port: 6379
      routes:
      - name: order-routes
        paths:
        - /orders
        strip_path: true
```

---

## 6. Aplicación con Jobs y CronJobs

### Objetivo
Gestionar tareas batch, procesamiento en segundo plano y trabajos programados.

### Configuración

#### 1. Data Processing Job
```yaml
# data-processing-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: daily-data-processing
  namespace: production
spec:
  parallelism: 4
  completions: 4
  backoffLimit: 3
  activeDeadlineSeconds: 3600  # 1 hora
  template:
    metadata:
      labels:
        app: data-processing
        job-type: batch
    spec:
      restartPolicy: OnFailure
      containers:
      - name: processor
        image: company/data-processor:1.0.0
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: redis-credentials
              key: url
        - name: S3_BUCKET
          value: "company-data-processing"
        - name: WORKER_ID
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "4Gi"
            cpu: "2"
        volumeMounts:
        - name: temp-storage
          mountPath: /tmp/processing
      volumes:
      - name: temp-storage
        emptyDir:
          sizeLimit: 10Gi
```

#### 2. Report Generation CronJob
```yaml
# report-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: weekly-reports
  namespace: production
spec:
  schedule: "0 2 * * 1"  # Every Monday at 2 AM
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 2
      activeDeadlineSeconds: 7200  # 2 horas
      template:
        metadata:
          labels:
            app: report-generator
            job-type: scheduled
        spec:
          restartPolicy: OnFailure
          containers:
          - name: report-generator
            image: company/report-generator:1.0.0
            env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: postgres-credentials
                  key: url
            - name: EMAIL_SERVICE_URL
              value: "http://notification-service:8080"
            - name: REPORT_TYPE
              value: "weekly"
            - name: OUTPUT_BUCKET
              value: "company-reports"
            resources:
              requests:
                memory: "1Gi"
                cpu: "500m"
              limits:
                memory: "2Gi"
                cpu: "1"
            volumeMounts:
            - name: report-storage
              mountPath: /app/reports
          volumes:
          - name: report-storage
            emptyDir:
              sizeLimit: 5Gi
```

#### 3. Cleanup CronJob
```yaml
# cleanup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-old-data
  namespace: production
spec:
  schedule: "0 3 * * *"  # Daily at 3 AM
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 1
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      backoffLimit: 1
      activeDeadlineSeconds: 1800  # 30 minutos
      template:
        metadata:
          labels:
            app: cleanup
            job-type: maintenance
        spec:
          restartPolicy: OnFailure
          containers:
          - name: cleanup
            image: company/cleanup-service:1.0.0
            env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: postgres-credentials
                  key: url
            - name: RETENTION_DAYS
              value: "90"
            - name: DRY_RUN
              value: "false"
            resources:
              requests:
                memory: "256Mi"
                cpu: "100m"
              limits:
                memory: "512Mi"
                cpu: "200m"
            command:
            - /bin/sh
            - -c
            - |
              echo "Starting cleanup job..."
              
              # Cleanup old logs
              psql $DATABASE_URL -c "DELETE FROM application_logs WHERE created_at < NOW() - INTERVAL '$RETENTION_DAYS days';"
              
              # Cleanup old sessions
              psql $DATABASE_URL -c "DELETE FROM user_sessions WHERE expires_at < NOW();"
              
              # Cleanup temp files
              psql $DATABASE_URL -c "DELETE FROM temp_uploads WHERE created_at < NOW() - INTERVAL '24 hours';"
              
              echo "Cleanup completed successfully"
```

---

## 7. Machine Learning Pipeline

### Objetivo
Implementar un pipeline de ML para entrenamiento, validación y serving de modelos.

### Configuración

#### 1. Model Training Job
```yaml
# ml-training-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: model-training-v2
  namespace: production
spec:
  parallelism: 1
  completions: 1
  backoffLimit: 2
  activeDeadlineSeconds: 14400  # 4 horas
  template:
    metadata:
      labels:
        app: ml-training
        model-version: v2
    spec:
      restartPolicy: OnFailure
      nodeSelector:
        accelerator: nvidia-tesla-v100
      containers:
      - name: trainer
        image: company/ml-trainer:2.0.0
        env:
        - name: MODEL_VERSION
          value: "v2"
        - name: DATASET_PATH
          value: "s3://company-ml-data/datasets/v2"
        - name: MODEL_OUTPUT_PATH
          value: "s3://company-ml-models/v2"
        - name: WANDB_API_KEY
          valueFrom:
            secretKeyRef:
              name: ml-secrets
              key: wandb-api-key
        resources:
          requests:
            memory: "8Gi"
            cpu: "4"
            nvidia.com/gpu: 1
          limits:
            memory: "16Gi"
            cpu: "8"
            nvidia.com/gpu: 1
        volumeMounts:
        - name: model-cache
          mountPath: /cache
        - name: shm
          mountPath: /dev/shm
      volumes:
      - name: model-cache
        emptyDir:
          sizeLimit: 50Gi
      - name: shm
        emptyDir:
          medium: Memory
          sizeLimit: 2Gi
```

#### 2. Model Serving Deployment
```yaml
# ml-serving.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-model-server
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ml-model-server
  template:
    metadata:
      labels:
        app: ml-model-server
        model-version: v2
    spec:
      initContainers:
      - name: model-downloader
        image: amazon/aws-cli:latest
        command:
        - /bin/sh
        - -c
        - |
          aws s3 sync s3://company-ml-models/v2/latest /models/
        volumeMounts:
        - name: model-storage
          mountPath: /models
      containers:
      - name: model-server
        image: tensorflow/serving:2.13.0
        ports:
        - containerPort: 8501  # REST API
        - containerPort: 8500  # gRPC
        env:
        - name: MODEL_NAME
          value: "recommendation_model"
        - name: MODEL_BASE_PATH
          value: "/models"
        args:
        - --model_name=$(MODEL_NAME)
        - --model_base_path=$(MODEL_BASE_PATH)
        - --rest_api_port=8501
        - --grpc_port=8500
        - --monitoring_config_file=/config/monitoring.config
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "4Gi"
            cpu: "2"
        livenessProbe:
          httpGet:
            path: /v1/models/recommendation_model
            port: 8501
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /v1/models/recommendation_model
            port: 8501
          initialDelaySeconds: 30
          periodSeconds: 10
        volumeMounts:
        - name: model-storage
          mountPath: /models
        - name: monitoring-config
          mountPath: /config
      volumes:
      - name: model-storage
        emptyDir:
          sizeLimit: 10Gi
      - name: monitoring-config
        configMap:
          name: tensorflow-monitoring-config
```

---

## 8. Sistema de Cola de Mensajes

### Objetivo
Implementar un sistema robusto de mensajería para comunicación asíncrona entre servicios.

### Configuración

#### 1. RabbitMQ Cluster
```yaml
# rabbitmq-cluster.yaml
apiVersion: rabbitmq.com/v1beta1
kind: RabbitmqCluster
metadata:
  name: rabbitmq-cluster
  namespace: production
spec:
  replicas: 3
  image: rabbitmq:3.12-management
  
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1
      memory: 2Gi
      
  rabbitmq:
    additionalConfig: |
      cluster_formation.peer_discovery_backend = rabbit_peer_discovery_k8s
      cluster_formation.k8s.host = kubernetes.default.svc.cluster.local
      cluster_formation.k8s.address_type = hostname
      vm_memory_high_watermark.relative = 0.8
      disk_free_limit.relative = 1.0
      collect_statistics_interval = 10000
      
  persistence:
    storageClassName: fast-ssd
    storage: 50Gi
    
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app.kubernetes.io/name: rabbitmq-cluster
        topologyKey: kubernetes.io/hostname
        
  override:
    statefulSet:
      spec:
        template:
          spec:
            containers:
            - name: rabbitmq
              env:
              - name: RABBITMQ_DEFAULT_USER
                valueFrom:
                  secretKeyRef:
                    name: rabbitmq-credentials
                    key: username
              - name: RABBITMQ_DEFAULT_PASS
                valueFrom:
                  secretKeyRef:
                    name: rabbitmq-credentials
                    key: password
```

#### 2. Message Producer Service
```yaml
# message-producer.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: message-producer
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: message-producer
  template:
    metadata:
      labels:
        app: message-producer
    spec:
      containers:
      - name: producer
        image: company/message-producer:1.0.0
        env:
        - name: RABBITMQ_URL
          valueFrom:
            secretKeyRef:
              name: rabbitmq-credentials
              key: url
        - name: EXCHANGE_NAME
          value: "events"
        - name: ROUTING_KEY_PREFIX
          value: "production"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

#### 3. Message Consumer Workers
```yaml
# message-consumers.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-processor
  namespace: production
spec:
  replicas: 5
  selector:
    matchLabels:
      app: order-processor
  template:
    metadata:
      labels:
        app: order-processor
        consumer-type: order
    spec:
      containers:
      - name: consumer
        image: company/order-processor:1.0.0
        env:
        - name: RABBITMQ_URL
          valueFrom:
            secretKeyRef:
              name: rabbitmq-credentials
              key: url
        - name: QUEUE_NAME
          value: "order_processing"
        - name: PREFETCH_COUNT
          value: "10"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: url
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "400m"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-processor
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: notification-processor
  template:
    metadata:
      labels:
        app: notification-processor
        consumer-type: notification
    spec:
      containers:
      - name: consumer
        image: company/notification-processor:1.0.0
        env:
        - name: RABBITMQ_URL
          valueFrom:
            secretKeyRef:
              name: rabbitmq-credentials
              key: url
        - name: QUEUE_NAME
          value: "notifications"
        - name: EMAIL_SERVICE_URL
          value: "http://email-service:8080"
        - name: SMS_SERVICE_URL
          value: "http://sms-service:8080"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
```

---

## 9. Aplicación Multi-tenant

### Objetivo
Implementar una aplicación SaaS multi-tenant con aislamiento de datos y recursos.

### Configuración

#### 1. Tenant Namespace Operator
```yaml
# tenant-controller.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tenant-controller
  namespace: system
spec:
  replicas: 2
  selector:
    matchLabels:
      app: tenant-controller
  template:
    metadata:
      labels:
        app: tenant-controller
    spec:
      serviceAccountName: tenant-controller
      containers:
      - name: controller
        image: company/tenant-controller:1.0.0
        env:
        - name: DEFAULT_RESOURCES_CPU
          value: "500m"
        - name: DEFAULT_RESOURCES_MEMORY
          value: "1Gi"
        - name: DEFAULT_STORAGE_CLASS
          value: "standard-ssd"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
```

#### 2. Tenant CRD
```yaml
# tenant-crd.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: tenants.multitenant.company.com
spec:
  group: multitenant.company.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              name:
                type: string
                minLength: 3
                maxLength: 63
              plan:
                type: string
                enum: ["basic", "premium", "enterprise"]
              resources:
                type: object
                properties:
                  cpu:
                    type: string
                  memory:
                    type: string
                  storage:
                    type: string
              limits:
                type: object
                properties:
                  maxPods:
                    type: integer
                  maxServices:
                    type: integer
          status:
            type: object
            properties:
              phase:
                type: string
                enum: ["Pending", "Active", "Suspended", "Terminating"]
              namespace:
                type: string
              endpoint:
                type: string
  scope: Cluster
  names:
    plural: tenants
    singular: tenant
    kind: Tenant
```

#### 3. Tenant Instance
```yaml
# tenant-example.yaml
apiVersion: multitenant.company.com/v1
kind: Tenant
metadata:
  name: acme-corp
spec:
  name: acme-corp
  plan: premium
  resources:
    cpu: "2"
    memory: "4Gi"
    storage: "100Gi"
  limits:
    maxPods: 50
    maxServices: 20
---
# Generated namespace and resources
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-acme-corp
  labels:
    tenant: acme-corp
    plan: premium
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-acme-corp-quota
  namespace: tenant-acme-corp
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "4Gi"
    limits.cpu: "4"
    limits.memory: "8Gi"
    persistentvolumeclaims: "10"
    pods: "50"
    services: "20"
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-isolation
  namespace: tenant-acme-corp
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: tenant-acme-corp
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: tenant-acme-corp
  - to: {}  # Allow external traffic
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
```

---

## 10. Sistema de Logs Distribuidos

### Objetivo
Implementar un sistema centralizado de logs para todas las aplicaciones con búsqueda y análisis en tiempo real.

### Configuración

#### 1. Elasticsearch Cluster
```yaml
# elasticsearch-cluster.yaml
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: production-logs
  namespace: logging
spec:
  version: 8.10.0
  nodeSets:
  - name: master
    count: 3
    config:
      node.roles: ["master"]
      xpack.security.enabled: true
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 50Gi
        storageClassName: fast-ssd
    podTemplate:
      spec:
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 2Gi
              cpu: 1
            limits:
              memory: 4Gi
              cpu: 2
          env:
          - name: ES_JAVA_OPTS
            value: "-Xms2g -Xmx2g"
  - name: data
    count: 3
    config:
      node.roles: ["data", "ingest"]
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 500Gi
        storageClassName: fast-ssd
    podTemplate:
      spec:
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 4Gi
              cpu: 2
            limits:
              memory: 8Gi
              cpu: 4
          env:
          - name: ES_JAVA_OPTS
            value: "-Xms4g -Xmx4g"
```

#### 2. Logstash Configuration
```yaml
# logstash.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logstash
  namespace: logging
spec:
  replicas: 3
  selector:
    matchLabels:
      app: logstash
  template:
    metadata:
      labels:
        app: logstash
    spec:
      containers:
      - name: logstash
        image: docker.elastic.co/logstash/logstash:8.10.0
        ports:
        - containerPort: 5044
        - containerPort: 9600
        env:
        - name: LS_JAVA_OPTS
          value: "-Xmx2g -Xms2g"
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "4Gi"
            cpu: "2"
        volumeMounts:
        - name: logstash-config
          mountPath: /usr/share/logstash/pipeline
        - name: logstash-settings
          mountPath: /usr/share/logstash/config
      volumes:
      - name: logstash-config
        configMap:
          name: logstash-config
      - name: logstash-settings
        configMap:
          name: logstash-settings
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: logstash-config
  namespace: logging
data:
  logstash.conf: |
    input {
      beats {
        port => 5044
      }
    }
    
    filter {
      if [kubernetes] {
        mutate {
          add_field => { 
            "application" => "%{[kubernetes][labels][app]}"
            "namespace" => "%{[kubernetes][namespace]}"
            "pod" => "%{[kubernetes][pod][name]}"
          }
        }
      }
      
      # Parse JSON logs
      if [message] =~ /^\{.*\}$/ {
        json {
          source => "message"
        }
      }
      
      # Parse application logs
      grok {
        match => { 
          "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} %{GREEDYDATA:content}"
        }
      }
      
      # Add geolocation for IP addresses
      if [client_ip] {
        geoip {
          source => "client_ip"
          target => "geoip"
        }
      }
    }
    
    output {
      elasticsearch {
        hosts => ["https://production-logs-es-http:9200"]
        user => "elastic"
        password => "${ELASTICSEARCH_PASSWORD}"
        ssl => true
        ssl_certificate_verification => false
        index => "logs-%{+YYYY.MM.dd}"
      }
    }
```

#### 3. Fluent Bit DaemonSet
```yaml
# fluent-bit.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: logging
spec:
  selector:
    matchLabels:
      app: fluent-bit
  template:
    metadata:
      labels:
        app: fluent-bit
    spec:
      serviceAccountName: fluent-bit
      containers:
      - name: fluent-bit
        image: fluent/fluent-bit:2.1.9
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        volumeMounts:
        - name: fluent-bit-config
          mountPath: /fluent-bit/etc/
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: fluent-bit-config
        configMap:
          name: fluent-bit-config
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
```

Estos casos de uso cubren los escenarios más comunes en entornos de producción, proporcionando configuraciones robustas, escalables y listas para uso empresarial.
