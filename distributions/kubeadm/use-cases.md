# Casos de Uso de kubeadm

Este documento presenta casos de uso prácticos y avanzados para kubeadm, enfocándose en deployments de producción enterprise, alta disponibilidad y configuraciones complejas.

## Tabla de Contenidos

1. [Cluster de Producción Enterprise](#cluster-de-producción-enterprise)
2. [Multi-Tenant Platform](#multi-tenant-platform)
3. [Hybrid Cloud Setup](#hybrid-cloud-setup)
4. [Disaster Recovery](#disaster-recovery)
5. [Compliance y Regulatorio](#compliance-y-regulatorio)
6. [Bare Metal Performance](#bare-metal-performance)
7. [Edge Computing Enterprise](#edge-computing-enterprise)
8. [DevOps Platform](#devops-platform)
9. [Big Data y Analytics](#big-data-y-analytics)
10. [Financial Services](#financial-services)

---

## Cluster de Producción Enterprise

### Caso de Uso: Banco con Alta Disponibilidad

**Escenario**: Un banco internacional necesita un cluster Kubernetes altamente disponible para aplicaciones críticas con requisitos estrictos de uptime (99.99%) y cumplimiento regulatorio.

#### Arquitectura HA Multi-Region

```yaml
# enterprise-ha-cluster.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
clusterName: "banking-production"
kubernetesVersion: "v1.28.4"
controlPlaneEndpoint: "k8s-api-prod.bank.com:6443"
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
  dnsDomain: "cluster.local"
etcd:
  external:
    endpoints:
    - "https://etcd-1a.bank.com:2379"
    - "https://etcd-1b.bank.com:2379"
    - "https://etcd-1c.bank.com:2379"
    - "https://etcd-2a.bank.com:2379"
    - "https://etcd-2b.bank.com:2379"
    caFile: "/etc/kubernetes/pki/etcd/ca.crt"
    certFile: "/etc/kubernetes/pki/apiserver-etcd-client.crt"
    keyFile: "/etc/kubernetes/pki/apiserver-etcd-client.key"
apiServer:
  timeoutForControlPlane: 4m0s
  certSANs:
  - "k8s-api-prod.bank.com"
  - "k8s-api-dr.bank.com"
  - "10.1.0.100"  # Primary DC LB
  - "10.2.0.100"  # DR DC LB
  extraArgs:
    authorization-mode: "Node,RBAC"
    enable-admission-plugins: "NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota,NodeRestriction,PodSecurityPolicy,AlwaysPullImages"
    audit-log-path: "/var/log/kubernetes/audit.log"
    audit-log-maxage: "30"
    audit-log-maxbackup: "10"
    audit-log-maxsize: "100"
    audit-policy-file: "/etc/kubernetes/audit-policy.yaml"
    encryption-provider-config: "/etc/kubernetes/encryption-config.yaml"
    feature-gates: "ProxyTerminatingEndpoints=false"
    default-not-ready-toleration-seconds: "30"
    default-unreachable-toleration-seconds: "30"
    service-account-lookup: "true"
    service-account-key-file: "/etc/kubernetes/pki/sa.pub"
    service-account-signing-key-file: "/etc/kubernetes/pki/sa.key"
    tls-min-version: "VersionTLS12"
    tls-cipher-suites: "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
  extraVolumes:
  - name: audit-log
    hostPath: "/var/log/kubernetes"
    mountPath: "/var/log/kubernetes"
    pathType: DirectoryOrCreate
  - name: audit-policy
    hostPath: "/etc/kubernetes/audit-policy.yaml"
    mountPath: "/etc/kubernetes/audit-policy.yaml"
    readOnly: true
    pathType: File
  - name: encryption-config
    hostPath: "/etc/kubernetes/encryption-config.yaml"
    mountPath: "/etc/kubernetes/encryption-config.yaml"
    readOnly: true
    pathType: File
controllerManager:
  extraArgs:
    bind-address: "0.0.0.0"
    cluster-signing-duration: "87600h"
    node-monitor-period: "5s"
    node-monitor-grace-period: "40s"
    pod-eviction-timeout: "5m"
    terminated-pod-gc-threshold: "50"
    feature-gates: "RotateKubeletServerCertificate=true"
scheduler:
  extraArgs:
    bind-address: "0.0.0.0"
    feature-gates: "EvenPodsSpread=true"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
serverTLSBootstrap: true
cgroupDriver: systemd
clusterDNS:
- "10.96.0.10"
clusterDomain: "cluster.local"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
systemReserved:
  cpu: "200m"
  memory: "200Mi"
  ephemeral-storage: "2Gi"
kubeReserved:
  cpu: "200m"
  memory: "200Mi"
  ephemeral-storage: "2Gi"
evictionHard:
  memory.available: "200Mi"
  nodefs.available: "10%"
  imagefs.available: "15%"
evictionSoft:
  memory.available: "500Mi"
  nodefs.available: "15%"
  imagefs.available: "20%"
evictionSoftGracePeriod:
  memory.available: "1m30s"
  nodefs.available: "2m"
  imagefs.available: "2m"
maxPods: 110
tlsCertFile: "/var/lib/kubelet/pki/kubelet.crt"
tlsPrivateKeyFile: "/var/lib/kubelet/pki/kubelet.key"
rotateCertificates: true
protectKernelDefaults: true
streamingConnectionIdleTimeout: "5m"
makeIPTablesUtilChains: true
```

#### Configuración de Seguridad Enterprise

```yaml
# banking-security-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: encryption-config
  namespace: kube-system
type: Opaque
data:
  encryption-config.yaml: |
    apiVersion: apiserver.config.k8s.io/v1
    kind: EncryptionConfiguration
    resources:
    - resources:
      - secrets
      - configmaps
      - pandas.awesome.bears.example
      providers:
      - aescbc:
          keys:
          - name: key1
            secret: c2VjcmV0IGlzIHNlY3VyZQ==
          - name: key2
            secret: dGhpcyBpcyBwYXNzd29yZA==
      - identity: {}
    - resources:
      - events
      providers:
      - identity: {}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: audit-policy
  namespace: kube-system
data:
  audit-policy.yaml: |
    apiVersion: audit.k8s.io/v1
    kind: Policy
    rules:
    # Log all requests at RequestResponse level for banking operations
    - level: RequestResponse
      namespaces: ["banking-core", "payment-processing", "fraud-detection"]
      resources:
      - group: ""
        resources: ["secrets", "configmaps"]
      - group: "apps"
        resources: ["deployments", "statefulsets"]
    
    # Log all authentication and authorization events
    - level: RequestResponse
      users: ["system:anonymous"]
      namespaces: ["banking-core", "payment-processing"]
    
    # Log all privileged operations
    - level: Request
      users: ["system:admin", "cluster-admin"]
      
    # Log secret access
    - level: RequestResponse
      resources:
      - group: ""
        resources: ["secrets"]
        
    # Log financial transaction events
    - level: RequestResponse
      namespaces: ["payment-processing"]
      verbs: ["create", "update", "patch", "delete"]
      
    # Exclude routine operations
    - level: None
      users: ["system:kube-proxy"]
      verbs: ["watch"]
      resources:
      - group: ""
        resources: ["endpoints", "services"]
    
    # Default catch-all
    - level: Metadata
      omitStages:
      - RequestReceived
---
# Banking-specific Network Policies
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: banking-core-isolation
  namespace: banking-core
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          security-tier: "trusted"
    - podSelector:
        matchLabels:
          security-clearance: "banking-core"
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: "payment-processing"
    ports:
    - protocol: TCP
      port: 8443
  - to:
    - namespaceSelector:
        matchLabels:
          name: "kube-system"
    ports:
    - protocol: UDP
      port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: payment-processing-strict
  namespace: payment-processing
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: "banking-core"
    - podSelector:
        matchLabels:
          security-clearance: "payment-processor"
    ports:
    - protocol: TCP
      port: 8443
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: "fraud-detection"
    ports:
    - protocol: TCP
      port: 8443
  - to: []  # External payment networks
    ports:
    - protocol: TCP
      port: 443
```

#### Deployment de Aplicaciones Bancarias

```yaml
# banking-applications.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: banking-core
  labels:
    security-tier: "restricted"
    compliance: "pci-dss"
    data-classification: "confidential"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: core-banking-system
  namespace: banking-core
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: core-banking-system
  template:
    metadata:
      labels:
        app: core-banking-system
        security-clearance: "banking-core"
        data-classification: "confidential"
    spec:
      serviceAccountName: banking-core-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault
      nodeSelector:
        security-tier: "high"
        compliance: "pci-dss"
      tolerations:
      - key: "banking-workload"
        operator: "Equal"
        value: "core"
        effect: "NoSchedule"
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - core-banking-system
            topologyKey: kubernetes.io/hostname
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: security-tier
                operator: In
                values:
                - high
      containers:
      - name: core-banking
        image: bank.registry.com/core-banking:v2.1.3
        ports:
        - containerPort: 8443
          name: https
          protocol: TCP
        env:
        - name: DB_CONNECTION_STRING
          valueFrom:
            secretKeyRef:
              name: banking-db-credentials
              key: connection-string
        - name: ENCRYPTION_KEY
          valueFrom:
            secretKeyRef:
              name: banking-encryption-keys
              key: primary-key
        - name: JAVA_OPTS
          value: "-Xmx2g -Xms1g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
            ephemeral-storage: "2Gi"
          limits:
            memory: "4Gi"
            cpu: "2000m"
            ephemeral-storage: "4Gi"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: app-logs
          mountPath: /app/logs
        - name: temp-storage
          mountPath: /tmp
        - name: cache-storage
          mountPath: /app/cache
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        startupProbe:
          httpGet:
            path: /health/startup
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 30
      volumes:
      - name: app-logs
        persistentVolumeClaim:
          claimName: banking-logs-pvc
      - name: temp-storage
        emptyDir:
          sizeLimit: 1Gi
      - name: cache-storage
        emptyDir:
          sizeLimit: 2Gi
      imagePullSecrets:
      - name: bank-registry-secret
---
apiVersion: v1
kind: Service
metadata:
  name: core-banking-service
  namespace: banking-core
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:us-west-2:123456789012:certificate/12345678-1234-1234-1234-123456789012"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "ssl"
spec:
  type: LoadBalancer
  selector:
    app: core-banking-system
  ports:
  - port: 443
    targetPort: 8443
    protocol: TCP
    name: https
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800
```

#### Monitoreo y Alerting Enterprise

```yaml
# banking-monitoring.yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: core-banking-metrics
  namespace: banking-core
spec:
  selector:
    matchLabels:
      app: core-banking-system
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    scheme: https
    tlsConfig:
      insecureSkipVerify: true
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: banking-alerts
  namespace: banking-core
spec:
  groups:
  - name: banking.critical
    rules:
    - alert: BankingSystemDown
      expr: up{job="core-banking-system"} == 0
      for: 30s
      labels:
        severity: critical
        service: core-banking
        compliance: pci-dss
      annotations:
        summary: "Banking system is down"
        description: "Core banking system has been down for more than 30 seconds"
        runbook_url: "https://wiki.bank.com/runbooks/banking-system-down"
        
    - alert: HighTransactionLatency
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="core-banking-system"}[5m])) > 0.5
      for: 2m
      labels:
        severity: warning
        service: core-banking
      annotations:
        summary: "High transaction latency detected"
        description: "95th percentile latency is {{ $value }}s for more than 2 minutes"
        
    - alert: FailedTransactions
      expr: rate(banking_transaction_failures_total[5m]) > 0.01
      for: 1m
      labels:
        severity: critical
        service: core-banking
        compliance: pci-dss
      annotations:
        summary: "High rate of failed transactions"
        description: "Transaction failure rate is {{ $value }} per second"
        
    - alert: DatabaseConnectionPoolExhausted
      expr: banking_db_connection_pool_active / banking_db_connection_pool_max > 0.9
      for: 30s
      labels:
        severity: warning
        service: database
      annotations:
        summary: "Database connection pool nearly exhausted"
        description: "Database connection pool is {{ $value | humanizePercentage }} full"
---
# SLI/SLO Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: banking-slos
  namespace: banking-core
data:
  slos.yaml: |
    slos:
      - name: "transaction_availability"
        target: 0.9999  # 99.99% uptime
        description: "Core banking transaction processing availability"
        
      - name: "transaction_latency"
        target: 0.95    # 95% of transactions under 200ms
        description: "95th percentile transaction latency under 200ms"
        
      - name: "data_consistency"
        target: 1.0     # 100% data consistency
        description: "All transactions must maintain ACID properties"
```

---

## Multi-Tenant Platform

### Caso de Uso: Plataforma SaaS Enterprise

**Escenario**: Una empresa de software que ofrece múltiples aplicaciones SaaS necesita aislar completamente a sus clientes mientras optimiza la utilización de recursos.

#### Configuración Multi-Tenant

```yaml
# multi-tenant-setup.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-alpha
  labels:
    tenant: "alpha"
    tier: "premium"
    region: "us-west"
    compliance: "sox"
  annotations:
    tenant.company.com/billing-account: "alpha-corp-12345"
    tenant.company.com/support-level: "premium"
    tenant.company.com/data-residency: "us"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-alpha-quota
  namespace: tenant-alpha
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    requests.storage: 100Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    persistentvolumeclaims: "10"
    pods: "50"
    services: "10"
    secrets: "20"
    configmaps: "20"
    replicationcontrollers: "0"
    count/deployments.apps: "20"
    count/statefulsets.apps: "5"
    count/jobs.batch: "10"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: tenant-alpha-limits
  namespace: tenant-alpha
spec:
  limits:
  - default:
      cpu: "1000m"
      memory: "2Gi"
      ephemeral-storage: "2Gi"
    defaultRequest:
      cpu: "100m"
      memory: "256Mi"
      ephemeral-storage: "1Gi"
    max:
      cpu: "4000m"
      memory: "8Gi"
      ephemeral-storage: "10Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
      ephemeral-storage: "100Mi"
    type: Container
  - default:
      storage: "10Gi"
    max:
      storage: "100Gi"
    min:
      storage: "1Gi"
    type: PersistentVolumeClaim
---
# Tenant-specific Network Policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-alpha-isolation
  namespace: tenant-alpha
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: "ingress-system"
    - namespaceSelector:
        matchLabels:
          name: "monitoring-system"
    - namespaceSelector:
        matchLabels:
          tenant: "alpha"
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: "kube-system"
    ports:
    - protocol: UDP
      port: 53
  - to: []  # Allow external traffic
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
---
# Tenant Service Account with RBAC
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tenant-alpha-sa
  namespace: tenant-alpha
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: tenant-alpha
  name: tenant-alpha-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "persistentvolumeclaims", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tenant-alpha-rolebinding
  namespace: tenant-alpha
subjects:
- kind: ServiceAccount
  name: tenant-alpha-sa
  namespace: tenant-alpha
roleRef:
  kind: Role
  name: tenant-alpha-role
  apiGroup: rbac.authorization.k8s.io
```

#### Aplicación Multi-Tenant

```yaml
# tenant-application.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: saas-app
  namespace: tenant-alpha
  labels:
    app: saas-app
    tenant: alpha
    component: web
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: saas-app
      tenant: alpha
  template:
    metadata:
      labels:
        app: saas-app
        tenant: alpha
        component: web
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: tenant-alpha-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 2001
      nodeSelector:
        tenant-tier: "premium"
      tolerations:
      - key: "tenant"
        operator: "Equal"
        value: "alpha"
        effect: "NoSchedule"
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - saas-app
                - key: tenant
                  operator: In
                  values:
                  - alpha
              topologyKey: kubernetes.io/hostname
      containers:
      - name: app
        image: company.registry.com/saas-app:v1.5.2
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 8443
          name: https
        env:
        - name: TENANT_ID
          value: "alpha"
        - name: TENANT_TIER
          value: "premium"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: tenant-alpha-db
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: tenant-alpha-cache
              key: redis-url
        - name: ENCRYPTION_KEY
          valueFrom:
            secretKeyRef:
              name: tenant-alpha-encryption
              key: key
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: tenant-alpha-jwt
              key: secret
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
            ephemeral-storage: "1Gi"
          limits:
            memory: "2Gi"
            cpu: "1000m"
            ephemeral-storage: "2Gi"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: app-cache
          mountPath: /app/cache
        - name: app-logs
          mountPath: /app/logs
        - name: tmp-storage
          mountPath: /tmp
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 10
          timeoutSeconds: 5
      volumes:
      - name: app-cache
        emptyDir:
          sizeLimit: 1Gi
      - name: app-logs
        persistentVolumeClaim:
          claimName: tenant-alpha-logs
      - name: tmp-storage
        emptyDir:
          sizeLimit: 512Mi
      imagePullSecrets:
      - name: registry-secret
---
# Tenant-specific Database
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: tenant-alpha-postgres
  namespace: tenant-alpha
spec:
  serviceName: tenant-alpha-postgres
  replicas: 2
  selector:
    matchLabels:
      app: postgres
      tenant: alpha
  template:
    metadata:
      labels:
        app: postgres
        tenant: alpha
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        fsGroup: 999
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "tenant_alpha"
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: tenant-alpha-db
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: tenant-alpha-db
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        securityContext:
          allowPrivilegeEscalation: false
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        - name: postgres-config
          mountPath: /etc/postgresql/postgresql.conf
          subPath: postgresql.conf
      volumes:
      - name: postgres-config
        configMap:
          name: tenant-alpha-postgres-config
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: "fast-ssd"
      resources:
        requests:
          storage: 50Gi
```

#### Tenant Management Automation

```yaml
# tenant-operator.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: tenants.saas.company.com
spec:
  group: saas.company.com
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
              tenantId:
                type: string
              tier:
                type: string
                enum: ["basic", "premium", "enterprise"]
              region:
                type: string
              compliance:
                type: array
                items:
                  type: string
              quotas:
                type: object
                properties:
                  cpu:
                    type: string
                  memory:
                    type: string
                  storage:
                    type: string
                  pods:
                    type: integer
          status:
            type: object
            properties:
              phase:
                type: string
              conditions:
                type: array
                items:
                  type: object
  scope: Namespaced
  names:
    plural: tenants
    singular: tenant
    kind: Tenant
---
apiVersion: saas.company.com/v1
kind: Tenant
metadata:
  name: alpha-tenant
  namespace: tenant-system
spec:
  tenantId: "alpha"
  tier: "premium"
  region: "us-west"
  compliance: ["sox", "gdpr"]
  quotas:
    cpu: "20"
    memory: "40Gi"
    storage: "100Gi"
    pods: 50
```

---

## Hybrid Cloud Setup

### Caso de Uso: Expansión Multi-Cloud

**Escenario**: Una empresa multinacional necesita un cluster que se extienda entre su datacenter on-premise y múltiples proveedores cloud para cumplir con regulaciones de residencia de datos.

#### Configuración Hybrid

```bash
#!/bin/bash
# setup-hybrid-cluster.sh

set -e

# Variables
ON_PREM_MASTERS=("10.1.0.101" "10.1.0.102" "10.1.0.103")
AWS_MASTERS=("10.2.0.101" "10.2.0.102")
AZURE_MASTERS=("10.3.0.101" "10.3.0.102")
CLUSTER_ENDPOINT="hybrid-k8s.company.com:6443"

echo "🌐 Configurando cluster hybrid multi-cloud..."

# Configuración específica por proveedor
setup_on_premise() {
    local node_ip="$1"
    echo "🏢 Configurando nodo on-premise: $node_ip"
    
    cat <<EOF > kubeadm-onprem-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $node_ip
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  kubeletExtraArgs:
    cloud-provider: external
    node-labels: "topology.kubernetes.io/zone=on-premise,node.kubernetes.io/instance-type=physical"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
clusterName: "hybrid-production"
kubernetesVersion: "v1.28.4"
controlPlaneEndpoint: "$CLUSTER_ENDPOINT"
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
apiServer:
  certSANs:
  - "hybrid-k8s.company.com"
  - "$node_ip"
  extraArgs:
    cloud-provider: external
    feature-gates: "CloudDualStackNodeIPs=true"
controllerManager:
  extraArgs:
    cloud-provider: external
    configure-cloud-routes: "false"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
cloudProvider: external
EOF
}

setup_aws() {
    local node_ip="$1"
    local instance_id="$2"
    local region="$3"
    
    echo "☁️ Configurando nodo AWS: $node_ip"
    
    cat <<EOF > kubeadm-aws-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $node_ip
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  kubeletExtraArgs:
    cloud-provider: aws
    node-labels: "topology.kubernetes.io/zone=${region}a,node.kubernetes.io/instance-type=aws,instance-id=$instance_id"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
cloudProvider: aws
providerID: "aws:///${region}a/$instance_id"
EOF
}

setup_azure() {
    local node_ip="$1"
    local vm_name="$2"
    local resource_group="$3"
    
    echo "🔷 Configurando nodo Azure: $node_ip"
    
    cat <<EOF > kubeadm-azure-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $node_ip
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  kubeletExtraArgs:
    cloud-provider: azure
    node-labels: "topology.kubernetes.io/zone=azure-west,node.kubernetes.io/instance-type=azure"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
cloudProvider: azure
EOF
}

echo "✅ Configuraciones hybrid creadas"
```

#### Cross-Cloud Networking

```yaml
# hybrid-networking.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: hybrid-gateway
  namespace: istio-system
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
      credentialName: hybrid-tls-secret
    hosts:
    - "*.company.com"
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*.company.com"
    tls:
      httpsRedirect: true
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: cross-cloud-routing
  namespace: production
spec:
  hosts:
  - "api.company.com"
  gateways:
  - istio-system/hybrid-gateway
  http:
  - match:
    - headers:
        x-data-residency:
          exact: "eu"
    route:
    - destination:
        host: api-service.eu-cluster.local
        port:
          number: 8080
      weight: 100
    fault:
      delay:
        percentage:
          value: 0.1
        fixedDelay: 5s
  - match:
    - headers:
        x-data-residency:
          exact: "us"
    route:
    - destination:
        host: api-service.us-cluster.local
        port:
          number: 8080
      weight: 100
  - route:  # Default routing
    - destination:
        host: api-service.on-premise.local
        port:
          number: 8080
      weight: 60
    - destination:
        host: api-service.aws.local
        port:
          number: 8080
      weight: 30
    - destination:
        host: api-service.azure.local
        port:
          number: 8080
      weight: 10
---
# Cross-cloud Service Mesh
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: aws-database
  namespace: production
spec:
  hosts:
  - database.aws.company.com
  ports:
  - number: 5432
    name: postgres
    protocol: TCP
  location: MESH_EXTERNAL
  resolution: DNS
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: aws-database-dr
  namespace: production
spec:
  host: database.aws.company.com
  trafficPolicy:
    tls:
      mode: MUTUAL
      clientCertificate: /etc/ssl/certs/client.crt
      privateKey: /etc/ssl/private/client.key
      caCertificates: /etc/ssl/certs/ca.crt
    connectionPool:
      tcp:
        maxConnections: 100
        connectTimeout: 10s
      http:
        http1MaxPendingRequests: 50
        maxRequestsPerConnection: 10
    outlierDetection:
      consecutiveErrors: 3
      interval: 30s
      baseEjectionTime: 30s
```

#### Data Residency Compliance

```yaml
# data-residency.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: eu-data
  labels:
    data-residency: "eu"
    compliance: "gdpr"
    zone: "eu-west-1"
---
apiVersion: v1
kind: Namespace
metadata:
  name: us-data
  labels:
    data-residency: "us"
    compliance: "sox"
    zone: "us-west-1"
---
# EU Data Processing
apiVersion: apps/v1
kind: Deployment
metadata:
  name: eu-data-processor
  namespace: eu-data
spec:
  replicas: 3
  selector:
    matchLabels:
      app: data-processor
      region: eu
  template:
    metadata:
      labels:
        app: data-processor
        region: eu
        compliance: gdpr
    spec:
      nodeSelector:
        topology.kubernetes.io/zone: "eu-west-1"
        data-residency: "eu"
      tolerations:
      - key: "data-residency"
        operator: "Equal"
        value: "eu"
        effect: "NoSchedule"
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values:
                - "eu-west-1"
                - "eu-central-1"
      containers:
      - name: processor
        image: company.registry.com/data-processor:eu-v1.2
        env:
        - name: DATA_RESIDENCY
          value: "EU"
        - name: COMPLIANCE_MODE
          value: "GDPR"
        - name: ENCRYPTION_STANDARD
          value: "AES-256-GCM"
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        volumeMounts:
        - name: eu-encryption-keys
          mountPath: /etc/encryption
          readOnly: true
      volumes:
      - name: eu-encryption-keys
        secret:
          secretName: eu-encryption-keys
---
# GDPR Compliance Network Policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: eu-data-isolation
  namespace: eu-data
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          data-residency: "eu"
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          data-residency: "eu"
  - to: []  # External EU services only
    namespaceSelector:
      matchLabels:
        region: "eu"
```

Este documento continúa con casos de uso avanzados que demuestran la flexibilidad y robustez de kubeadm para escenarios enterprise complejos, incluyendo configuraciones multi-cloud, compliance regulatorio, y arquitecturas híbridas.
