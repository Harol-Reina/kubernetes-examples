# Helm - Ejemplos y Guías Prácticas

Esta guía proporciona ejemplos prácticos y comandos útiles de Helm para la gestión de aplicaciones en Kubernetes.

## Tabla de Contenidos

1. [Instalación y Configuración](#instalación-y-configuración)
2. [Conceptos Básicos](#conceptos-básicos)
3. [Trabajando con Charts](#trabajando-con-charts)
4. [Gestión de Releases](#gestión-de-releases)
5. [Repositorios de Charts](#repositorios-de-charts)
6. [Creación de Charts Personalizados](#creación-de-charts-personalizados)
7. [Templates y Values](#templates-y-values)
8. [Hooks y Tests](#hooks-y-tests)
9. [Charts Dependencies](#charts-dependencies)
10. [Helm en CI/CD](#helm-en-cicd)
11. [Security y Best Practices](#security-y-best-practices)
12. [Troubleshooting](#troubleshooting)
13. [Plugins Útiles](#plugins-útiles)
14. [Scripts de Automatización](#scripts-de-automatización)
15. [Ejemplos de Charts Complejos](#ejemplos-de-charts-complejos)

---

## Instalación y Configuración

### Instalación de Helm

```bash
# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# macOS
brew install helm

# Windows (con Chocolatey)
choco install kubernetes-helm

# Verificar instalación
helm version
```

### Configuración Inicial

```bash
# Agregar repositorio oficial de charts
helm repo add stable https://charts.helm.sh/stable
helm repo add bitnami https://charts.bitnami.com/bitnami

# Actualizar repositorios
helm repo update

# Listar repositorios
helm repo list

# Buscar charts
helm search repo nginx
helm search hub wordpress
```

---

## Conceptos Básicos

### Comandos Fundamentales

```bash
# Instalar un chart
helm install my-release bitnami/nginx

# Listar releases
helm list

# Ver estado de un release
helm status my-release

# Obtener información de un chart
helm show chart bitnami/nginx
helm show values bitnami/nginx
helm show readme bitnami/nginx

# Actualizar un release
helm upgrade my-release bitnami/nginx

# Desinstalar un release
helm uninstall my-release

# Ver historial de releases
helm history my-release
```

### Ejemplo Básico de Instalación

```bash
# Instalar WordPress con valores personalizados
helm install my-wordpress bitnami/wordpress \
  --set wordpressUsername=admin \
  --set wordpressPassword=secretpassword \
  --set mariadb.auth.rootPassword=secretpassword \
  --set service.type=LoadBalancer

# Ver el estado
helm status my-wordpress

# Obtener contraseña generada
echo Username: admin
echo Password: $(kubectl get secret --namespace default my-wordpress -o jsonpath="{.data.wordpress-password}" | base64 -d)
```

---

## Trabajando con Charts

### Explorar Charts

```bash
# Buscar charts
helm search repo database
helm search hub mongodb

# Obtener información detallada
helm show chart bitnami/postgresql
helm show values bitnami/postgresql

# Descargar chart para inspección
helm pull bitnami/postgresql
tar -zxvf postgresql-*.tgz
cd postgresql/
ls -la
```

### Dry Run y Testing

```bash
# Dry run de instalación
helm install my-app bitnami/nginx --dry-run --debug

# Validar templates
helm template my-app bitnami/nginx

# Lint del chart
helm lint ./my-chart

# Test del chart instalado
helm test my-release
```

---

## Gestión de Releases

### Lifecycle de Releases

```bash
# Instalar con namespace específico
helm install my-app bitnami/nginx --namespace production --create-namespace

# Upgrade con nuevos valores
helm upgrade my-app bitnami/nginx --set replicaCount=3

# Rollback a versión anterior
helm rollback my-app 1

# Ver diferencias antes del upgrade
helm diff upgrade my-app bitnami/nginx --set replicaCount=5

# Upgrade condicional (solo si hay cambios)
helm upgrade my-app bitnami/nginx --reuse-values --wait

# Desinstalar manteniendo historia
helm uninstall my-app --keep-history
```

### Archivo de Valores

```yaml
# values.yaml
replicaCount: 3

image:
  repository: nginx
  tag: "1.21"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: myapp.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: myapp-tls
      hosts:
        - myapp.example.com

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

nodeSelector: {}
tolerations: []
affinity: {}
```

### Instalación con Valores Personalizados

```bash
# Usando archivo de valores
helm install my-app bitnami/nginx -f values.yaml

# Combinando archivo y parámetros
helm install my-app bitnami/nginx -f values.yaml --set replicaCount=5

# Múltiples archivos de valores
helm install my-app bitnami/nginx -f values-base.yaml -f values-production.yaml

# Valores desde URL
helm install my-app bitnami/nginx -f https://raw.githubusercontent.com/user/repo/main/values.yaml
```

---

## Repositorios de Charts

### Gestión de Repositorios

```bash
# Agregar repositorios populares
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add elastic https://helm.elastic.co
helm repo add jetstack https://charts.jetstack.io

# Actualizar repositorios
helm repo update

# Eliminar repositorio
helm repo remove stable

# Verificar repositorios
helm repo list
```

### Crear Repositorio Local

```bash
# Crear directorio para charts
mkdir my-chart-repo
cd my-chart-repo

# Crear índice de repositorio
helm repo index . --url http://my-repo.example.com

# Servir repositorio localmente
python3 -m http.server 8080

# Agregar repositorio local
helm repo add local http://localhost:8080
```

---

## Creación de Charts Personalizados

### Crear Chart Básico

```bash
# Crear estructura de chart
helm create my-app

# Estructura generada:
# my-app/
#   Chart.yaml
#   values.yaml
#   templates/
#     deployment.yaml
#     service.yaml
#     ingress.yaml
#     _helpers.tpl
#   .helmignore
```

### Chart.yaml Avanzado

```yaml
# Chart.yaml
apiVersion: v2
name: my-microservice
description: A Helm chart for my microservice application
type: application
version: 0.1.0
appVersion: "1.0.0"
home: https://github.com/myorg/my-microservice
sources:
  - https://github.com/myorg/my-microservice
maintainers:
  - name: DevOps Team
    email: devops@myorg.com
keywords:
  - microservice
  - api
  - backend
dependencies:
  - name: postgresql
    version: 11.9.13
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
  - name: redis
    version: 17.3.7
    repository: https://charts.bitnami.com/bitnami
    condition: redis.enabled
annotations:
  category: Application
  licenses: Apache-2.0
```

### Templates Avanzados

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-app.fullname" . }}
  labels:
    {{- include "my-app.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "my-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "my-app.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "my-app.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort }}
              protocol: TCP
          env:
            {{- range $key, $value := .Values.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
            {{- if .Values.postgresql.enabled }}
            - name: DATABASE_URL
              value: "postgresql://{{ .Values.postgresql.auth.username }}:{{ .Values.postgresql.auth.password }}@{{ include "my-app.fullname" . }}-postgresql:5432/{{ .Values.postgresql.auth.database }}"
            {{- end }}
          envFrom:
            {{- if .Values.configMap.enabled }}
            - configMapRef:
                name: {{ include "my-app.fullname" . }}-config
            {{- end }}
            {{- if .Values.secret.enabled }}
            - secretRef:
                name: {{ include "my-app.fullname" . }}-secret
            {{- end }}
          livenessProbe:
            {{- toYaml .Values.livenessProbe | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.readinessProbe | nindent 12 }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          {{- with .Values.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

### Helper Templates

```yaml
# templates/_helpers.tpl
{{/*
Expand the name of the chart.
*/}}
{{- define "my-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "my-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "my-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "my-app.labels" -}}
helm.sh/chart: {{ include "my-app.chart" . }}
{{ include "my-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "my-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "my-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "my-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "my-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Database URL helper
*/}}
{{- define "my-app.databaseUrl" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "postgresql://%s:%s@%s-postgresql:5432/%s" .Values.postgresql.auth.username .Values.postgresql.auth.password (include "my-app.fullname" .) .Values.postgresql.auth.database }}
{{- else }}
{{- .Values.externalDatabase.url }}
{{- end }}
{{- end }}
```

---

## Templates y Values

### Condicionales y Loops

```yaml
# templates/configmap.yaml
{{- if .Values.configMap.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "my-app.fullname" . }}-config
  labels:
    {{- include "my-app.labels" . | nindent 4 }}
data:
  {{- range $key, $value := .Values.configMap.data }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
  {{- if .Values.database.enabled }}
  database.host: {{ .Values.database.host | quote }}
  database.port: {{ .Values.database.port | quote }}
  {{- end }}
{{- end }}
```

### Named Templates

```yaml
# templates/_config.tpl
{{- define "my-app.config" -}}
app:
  name: {{ include "my-app.fullname" . }}
  version: {{ .Chart.AppVersion }}
  environment: {{ .Values.environment }}
database:
  {{- if .Values.postgresql.enabled }}
  type: postgresql
  host: {{ include "my-app.fullname" . }}-postgresql
  port: 5432
  {{- else }}
  type: {{ .Values.externalDatabase.type }}
  host: {{ .Values.externalDatabase.host }}
  port: {{ .Values.externalDatabase.port }}
  {{- end }}
{{- end }}

# Uso en templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "my-app.fullname" . }}-config
data:
  app.yaml: |
    {{- include "my-app.config" . | nindent 4 }}
```

### Values con Validación

```yaml
# values.yaml con comentarios de validación
# Configuración de la aplicación
replicaCount: 1 # @schema {"type": "integer", "minimum": 1}

image:
  repository: nginx # @schema {"type": "string", "pattern": "^[a-z0-9.-]+/[a-z0-9.-]+$"}
  tag: "1.21" # @schema {"type": "string"}
  pullPolicy: IfNotPresent # @schema {"enum": ["Always", "Never", "IfNotPresent"]}

# Configuración del servicio
service:
  type: ClusterIP # @schema {"enum": ["ClusterIP", "NodePort", "LoadBalancer"]}
  port: 80 # @schema {"type": "integer", "minimum": 1, "maximum": 65535}
  targetPort: 8080

# Configuración de recursos
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

# Autoescalado
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80

# Base de datos
postgresql:
  enabled: true
  auth:
    username: myapp
    password: changeme
    database: myapp_db

# Configuración externa cuando postgresql.enabled = false
externalDatabase:
  type: postgresql
  host: ""
  port: 5432
  username: ""
  password: ""
  database: ""
```

---

## Hooks y Tests

### Pre/Post Install Hooks

```yaml
# templates/hooks/pre-install-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "my-app.fullname" . }}-pre-install
  labels:
    {{- include "my-app.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: pre-install
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        command:
        - /bin/sh
        - -c
        - |
          echo "Running pre-install tasks..."
          # Crear base de datos, migrar esquemas, etc.
          ./scripts/setup-database.sh
          echo "Pre-install completed"
```

### Tests

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "my-app.fullname" . }}-test"
  labels:
    {{- include "my-app.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
spec:
  restartPolicy: Never
  containers:
  - name: wget
    image: busybox
    command: ['wget']
    args: ['{{ include "my-app.fullname" . }}:{{ .Values.service.port }}']
```

### Hooks Avanzados

```yaml
# templates/hooks/backup-hook.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "my-app.fullname" . }}-backup-{{ .Release.Revision }}
  annotations:
    "helm.sh/hook": pre-upgrade
    "helm.sh/hook-weight": "-10"
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: backup
        image: postgres:13
        env:
        - name: PGPASSWORD
          value: {{ .Values.postgresql.auth.password }}
        command:
        - /bin/sh
        - -c
        - |
          pg_dump -h {{ include "my-app.fullname" . }}-postgresql \
                  -U {{ .Values.postgresql.auth.username }} \
                  -d {{ .Values.postgresql.auth.database }} \
                  > /backup/backup-$(date +%Y%m%d-%H%M%S).sql
        volumeMounts:
        - name: backup-storage
          mountPath: /backup
      volumes:
      - name: backup-storage
        persistentVolumeClaim:
          claimName: {{ include "my-app.fullname" . }}-backup
```

---

## Charts Dependencies

### Gestión de Dependencias

```yaml
# Chart.yaml con dependencias
dependencies:
  - name: postgresql
    version: "11.9.13"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
  - name: redis
    version: "17.3.7"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled
  - name: nginx-ingress-controller
    version: "9.3.8"
    repository: "https://charts.bitnami.com/bitnami"
    condition: ingress.enabled
```

```bash
# Actualizar dependencias
helm dependency update

# Construir dependencias
helm dependency build

# Listar dependencias
helm dependency list
```

### Values para Dependencias

```yaml
# values.yaml
postgresql:
  enabled: true
  auth:
    username: myapp
    password: secretpassword
    database: myapp_production
  primary:
    persistence:
      enabled: true
      size: 10Gi
      storageClass: "fast-ssd"
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true

redis:
  enabled: true
  auth:
    enabled: true
    password: redispassword
  master:
    persistence:
      enabled: true
      size: 5Gi
  replica:
    replicaCount: 1

nginx-ingress-controller:
  enabled: true
  service:
    type: LoadBalancer
  metrics:
    enabled: true
```

---

## Helm en CI/CD

### GitLab CI/CD Example

```yaml
# .gitlab-ci.yml
stages:
  - build
  - test
  - deploy

variables:
  HELM_CHART_PATH: "./helm-chart"
  KUBECONFIG: /tmp/kubeconfig

before_script:
  - helm version
  - kubectl version --client

lint-chart:
  stage: test
  script:
    - helm lint $HELM_CHART_PATH
    - helm template test $HELM_CHART_PATH --debug

deploy-staging:
  stage: deploy
  environment:
    name: staging
  script:
    - echo $KUBECONFIG_STAGING | base64 -d > $KUBECONFIG
    - helm upgrade --install myapp-staging $HELM_CHART_PATH 
        --namespace staging 
        --create-namespace
        --values $HELM_CHART_PATH/values-staging.yaml
        --set image.tag=$CI_COMMIT_SHA
        --wait
  only:
    - develop

deploy-production:
  stage: deploy
  environment:
    name: production
  script:
    - echo $KUBECONFIG_PRODUCTION | base64 -d > $KUBECONFIG
    - helm upgrade --install myapp-production $HELM_CHART_PATH 
        --namespace production 
        --create-namespace
        --values $HELM_CHART_PATH/values-production.yaml
        --set image.tag=$CI_COMMIT_TAG
        --wait
  only:
    - tags
  when: manual
```

### GitHub Actions Example

```yaml
# .github/workflows/deploy.yml
name: Deploy with Helm

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-west-2
        
    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      
    - name: Setup Helm
      uses: azure/setup-helm@v3
      with:
        version: '3.10.0'
        
    - name: Update kubeconfig
      run: |
        aws eks update-kubeconfig --name my-cluster --region us-west-2
        
    - name: Lint Helm chart
      run: |
        helm lint ./helm-chart
        
    - name: Deploy to staging
      if: github.ref == 'refs/heads/main'
      run: |
        helm upgrade --install myapp-staging ./helm-chart \
          --namespace staging \
          --create-namespace \
          --values ./helm-chart/values-staging.yaml \
          --set image.tag=${{ github.sha }} \
          --wait
          
    - name: Deploy to production
      if: startsWith(github.ref, 'refs/tags/v')
      run: |
        helm upgrade --install myapp-production ./helm-chart \
          --namespace production \
          --create-namespace \
          --values ./helm-chart/values-production.yaml \
          --set image.tag=${{ github.ref_name }} \
          --wait
```

---

## Security y Best Practices

### Security Scanning

```bash
# Instalar plugin de seguridad
helm plugin install https://github.com/fabiosb/helm-security

# Escanear chart por vulnerabilidades
helm security scan ./my-chart

# Validar RBAC
helm template ./my-chart | kubectl auth can-i --list --as=system:serviceaccount:default:my-service-account -f -
```

### Chart Security Best Practices

```yaml
# templates/deployment.yaml - Security Best Practices
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-app.fullname" . }}
spec:
  template:
    spec:
      # Security Context para el Pod
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: {{ .Chart.Name }}
        # Security Context para el Container
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
        # Resources limits (security requirement)
        resources:
          limits:
            cpu: {{ .Values.resources.limits.cpu }}
            memory: {{ .Values.resources.limits.memory }}
          requests:
            cpu: {{ .Values.resources.requests.cpu }}
            memory: {{ .Values.resources.requests.memory }}
        # Health checks (security requirement)
        livenessProbe:
          httpGet:
            path: /health
            port: http
        readinessProbe:
          httpGet:
            path: /ready
            port: http
```

### Network Policies Template

```yaml
# templates/networkpolicy.yaml
{{- if .Values.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "my-app.fullname" . }}
  labels:
    {{- include "my-app.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "my-app.selectorLabels" . | nindent 6 }}
  policyTypes:
  {{- if .Values.networkPolicy.ingress }}
  - Ingress
  {{- end }}
  {{- if .Values.networkPolicy.egress }}
  - Egress
  {{- end }}
  {{- if .Values.networkPolicy.ingress }}
  ingress:
  {{- range .Values.networkPolicy.ingress }}
  - from:
    {{- if .namespaceSelector }}
    - namespaceSelector:
        {{- toYaml .namespaceSelector | nindent 8 }}
    {{- end }}
    {{- if .podSelector }}
    - podSelector:
        {{- toYaml .podSelector | nindent 8 }}
    {{- end }}
    {{- if .ports }}
    ports:
    {{- range .ports }}
    - protocol: {{ .protocol }}
      port: {{ .port }}
    {{- end }}
    {{- end }}
  {{- end }}
  {{- end }}
  {{- if .Values.networkPolicy.egress }}
  egress:
  {{- range .Values.networkPolicy.egress }}
  - to:
    {{- if .namespaceSelector }}
    - namespaceSelector:
        {{- toYaml .namespaceSelector | nindent 8 }}
    {{- end }}
    {{- if .podSelector }}
    - podSelector:
        {{- toYaml .podSelector | nindent 8 }}
    {{- end }}
    {{- if .ports }}
    ports:
    {{- range .ports }}
    - protocol: {{ .protocol }}
      port: {{ .port }}
    {{- end }}
    {{- end }}
  {{- end }}
  {{- end }}
{{- end }}
```

---

## Troubleshooting

### Comandos de Debugging

```bash
# Verificar sintaxis del chart
helm lint ./my-chart

# Debug de templates
helm template my-release ./my-chart --debug

# Ver valores computados
helm get values my-release

# Ver manifest generado
helm get manifest my-release

# Ver hooks
helm get hooks my-release

# Revisar historial
helm history my-release

# Estado detallado
helm status my-release --show-resources

# Rollback con debug
helm rollback my-release 1 --debug
```

### Script de Troubleshooting

```bash
#!/bin/bash
# helm-debug.sh - Script para debuggear problemas con Helm

RELEASE_NAME=$1
NAMESPACE=${2:-default}

if [ -z "$RELEASE_NAME" ]; then
    echo "Usage: $0 <release-name> [namespace]"
    exit 1
fi

echo "=== HELM TROUBLESHOOTING REPORT ==="
echo "Release: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"
echo "Date: $(date)"
echo ""

echo "=== RELEASE STATUS ==="
helm status $RELEASE_NAME -n $NAMESPACE
echo ""

echo "=== RELEASE VALUES ==="
helm get values $RELEASE_NAME -n $NAMESPACE
echo ""

echo "=== RELEASE MANIFEST ==="
helm get manifest $RELEASE_NAME -n $NAMESPACE
echo ""

echo "=== KUBERNETES RESOURCES ==="
kubectl get all -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE
echo ""

echo "=== PODS DESCRIPTION ==="
kubectl describe pods -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE
echo ""

echo "=== RECENT EVENTS ==="
kubectl get events -n $NAMESPACE --sort-by=.metadata.creationTimestamp | tail -20
echo ""

echo "=== LOGS FROM PODS ==="
for pod in $(kubectl get pods -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -o name); do
    echo "--- Logs from $pod ---"
    kubectl logs $pod -n $NAMESPACE --tail=50
    echo ""
done
```

---

## Plugins Útiles

### Instalación de Plugins

```bash
# Plugin para ver diferencias
helm plugin install https://github.com/databus23/helm-diff

# Plugin para secrets
helm plugin install https://github.com/jkroepke/helm-secrets

# Plugin para documentación
helm plugin install https://github.com/norwoodj/helm-docs

# Plugin para validación de esquemas
helm plugin install https://github.com/karuppiah7890/helm-schema-gen

# Listar plugins instalados
helm plugin list
```

### Uso de Plugins

```bash
# Ver diferencias antes del upgrade
helm diff upgrade my-release ./my-chart

# Trabajar con secrets encriptados
helm secrets install my-release ./my-chart -f secrets://values-secret.yaml

# Generar documentación
helm-docs

# Generar esquema de values
helm schema-gen values.yaml > values.schema.json
```

---

## Scripts de Automatización

### Script de Deployment Multi-Environment

```bash
#!/bin/bash
# deploy-multi-env.sh - Deploy a múltiples entornos

set -e

CHART_PATH="./helm-chart"
ENVIRONMENTS=("development" "staging" "production")
DEFAULT_TIMEOUT="300s"

# Función para mostrar ayuda
show_help() {
    echo "Multi-Environment Deployment Script"
    echo ""
    echo "Usage: $0 [OPTIONS] <release-name>"
    echo ""
    echo "Options:"
    echo "  -e, --env ENV          Deploy to specific environment (dev|staging|prod)"
    echo "  -a, --all              Deploy to all environments"
    echo "  -c, --chart PATH       Path to Helm chart (default: ./helm-chart)"
    echo "  -t, --timeout TIMEOUT  Timeout for deployment (default: 300s)"
    echo "  -d, --dry-run          Perform dry run"
    echo "  -h, --help             Show this help"
    echo ""
}

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -a|--all)
            DEPLOY_ALL=true
            shift
            ;;
        -c|--chart)
            CHART_PATH="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            RELEASE_NAME="$1"
            shift
            ;;
    esac
done

# Validar argumentos
if [ -z "$RELEASE_NAME" ]; then
    echo "Error: Release name is required"
    show_help
    exit 1
fi

# Función para deploy en un entorno
deploy_to_environment() {
    local env=$1
    local release_name="${RELEASE_NAME}-${env}"
    local values_file="${CHART_PATH}/values-${env}.yaml"
    local namespace="$env"
    
    echo "=== Deploying to $env environment ==="
    
    # Verificar que el archivo de valores existe
    if [ ! -f "$values_file" ]; then
        echo "Warning: Values file $values_file not found, using default values"
        values_file=""
    fi
    
    # Construir comando helm
    local helm_cmd="helm upgrade --install $release_name $CHART_PATH"
    helm_cmd="$helm_cmd --namespace $namespace --create-namespace"
    helm_cmd="$helm_cmd --timeout ${TIMEOUT:-$DEFAULT_TIMEOUT}"
    helm_cmd="$helm_cmd --wait"
    
    if [ -n "$values_file" ]; then
        helm_cmd="$helm_cmd --values $values_file"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        helm_cmd="$helm_cmd --dry-run"
    fi
    
    # Ejecutar deployment
    echo "Executing: $helm_cmd"
    eval $helm_cmd
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully deployed to $env"
        
        # Mostrar status si no es dry run
        if [ "$DRY_RUN" != true ]; then
            helm status $release_name -n $namespace
        fi
    else
        echo "❌ Failed to deploy to $env"
        return 1
    fi
    
    echo ""
}

# Validar chart
echo "Validating Helm chart..."
helm lint $CHART_PATH

# Realizar deployment
if [ "$DEPLOY_ALL" = true ]; then
    echo "Deploying to all environments..."
    for env in "${ENVIRONMENTS[@]}"; do
        deploy_to_environment $env
    done
elif [ -n "$ENVIRONMENT" ]; then
    deploy_to_environment $ENVIRONMENT
else
    echo "Error: Specify environment with -e or use -a for all environments"
    exit 1
fi

echo "Deployment completed!"
```

### Script de Backup de Releases

```bash
#!/bin/bash
# backup-helm-releases.sh - Backup de releases de Helm

BACKUP_DIR="helm-backups/$(date +%Y%m%d-%H%M%S)"
NAMESPACE=${1:-"--all-namespaces"}

echo "Creating Helm releases backup..."
mkdir -p $BACKUP_DIR

# Obtener lista de releases
if [ "$NAMESPACE" = "--all-namespaces" ]; then
    releases=$(helm list -A -o json | jq -r '.[] | "\(.name):\(.namespace)"')
else
    releases=$(helm list -n $NAMESPACE -o json | jq -r '.[] | "\(.name):\(.namespace)"')
fi

# Backup de cada release
for release_info in $releases; do
    release_name=$(echo $release_info | cut -d':' -f1)
    release_namespace=$(echo $release_info | cut -d':' -f2)
    
    echo "Backing up release: $release_name in namespace: $release_namespace"
    
    # Crear directorio para el release
    release_dir="$BACKUP_DIR/$release_namespace/$release_name"
    mkdir -p $release_dir
    
    # Backup de valores
    helm get values $release_name -n $release_namespace > "$release_dir/values.yaml"
    
    # Backup de manifest
    helm get manifest $release_name -n $release_namespace > "$release_dir/manifest.yaml"
    
    # Backup de hooks
    helm get hooks $release_name -n $release_namespace > "$release_dir/hooks.yaml" 2>/dev/null || true
    
    # Backup de metadatos
    helm status $release_name -n $release_namespace -o json > "$release_dir/status.json"
done

# Comprimir backup
tar -czf "$BACKUP_DIR.tar.gz" -C $(dirname $BACKUP_DIR) $(basename $BACKUP_DIR)
rm -rf $BACKUP_DIR

echo "Backup completed: $BACKUP_DIR.tar.gz"
```

Esta guía cubre los aspectos más importantes de Helm para la gestión de aplicaciones en Kubernetes, desde conceptos básicos hasta técnicas avanzadas de automatización y troubleshooting.
