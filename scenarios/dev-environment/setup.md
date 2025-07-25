# Configuración de Entorno de Desarrollo en Kubernetes

Esta guía proporciona todo lo necesario para configurar un entorno de desarrollo completo en Kubernetes, optimizado para desarrolladores que necesitan un ambiente local robusto y escalable.

## Tabla de Contenidos

1. [Introducción](#introducción)
2. [Prerequisitos](#prerequisitos)
3. [Configuración Inicial](#configuración-inicial)
4. [Componentes del Entorno](#componentes-del-entorno)
5. [Configuraciones por Herramienta](#configuraciones-por-herramienta)
6. [Workflows de Desarrollo](#workflows-de-desarrollo)
7. [Hot Reload y Live Development](#hot-reload-y-live-development)
8. [Debugging en Kubernetes](#debugging-en-kubernetes)
9. [Testing Local](#testing-local)
10. [Monitoreo y Observabilidad](#monitoreo-y-observabilidad)
11. [Troubleshooting](#troubleshooting)
12. [Mejores Prácticas](#mejores-prácticas)

---

## Introducción

Un entorno de desarrollo en Kubernetes permite a los desarrolladores trabajar en un ambiente que replica fielmente la producción, facilitando el desarrollo, testing y debugging de aplicaciones cloud-native.

### Beneficios

- **Paridad con Producción**: Mismo stack tecnológico
- **Microservicios**: Desarrollo de arquitecturas distribuidas
- **Escalabilidad**: Testing de comportamiento bajo carga
- **DevOps Integration**: CI/CD desde el inicio
- **Team Collaboration**: Entornos consistentes para todo el equipo

---

## Prerequisitos

### Software Requerido

#### 1. Herramientas Base
```bash
# Docker Desktop o Docker Engine
docker --version
# Docker version 24.0.0+

# kubectl
kubectl version --client
# v1.28.0+

# Minikube (recomendado para desarrollo local)
minikube version
# v1.32.0+

# Helm (gestor de paquetes)
helm version
# v3.13.0+

# Git
git --version
# 2.40.0+
```

#### 2. Herramientas de Desarrollo
```bash
# Skaffold para desarrollo iterativo
skaffold version
# v2.8.0+

# Tilt para desarrollo local
tilt version
# v0.33.0+

# Telepresence para debugging remoto
telepresence version
# 2.15.0+

# k9s para management visual
k9s version
# v0.28.0+
```

#### 3. Extensiones Recomendadas (VS Code)
```json
{
  "recommendations": [
    "ms-kubernetes-tools.vscode-kubernetes-tools",
    "ms-vscode.vscode-docker",
    "redhat.vscode-yaml",
    "ms-vscode-remote.remote-containers",
    "GoogleCloudTools.cloudcode",
    "ms-vscode.vscode-json"
  ]
}
```

### Configuración del Sistema

#### Recursos Mínimos
- **CPU**: 4 cores
- **RAM**: 8GB (recomendado 16GB)
- **Disco**: 50GB libres
- **Virtualización**: Habilitada en BIOS

#### Configuración de Minikube
```bash
# Configurar Minikube con recursos adecuados
minikube config set driver docker
minikube config set cpus 4
minikube config set memory 8192
minikube config set disk-size 40g

# Habilitar addons necesarios
minikube addons enable dashboard
minikube addons enable metrics-server
minikube addons enable ingress
minikube addons enable registry
minikube addons enable storage-provisioner
```

---

## Configuración Inicial

### 1. Inicializar Cluster de Desarrollo

```bash
#!/bin/bash
# setup-dev-cluster.sh

echo "🚀 Configurando cluster de desarrollo..."

# Iniciar Minikube
minikube start --driver=docker \
  --cpus=4 \
  --memory=8192 \
  --disk-size=40g \
  --kubernetes-version=v1.28.0

# Configurar registry local
minikube addons enable registry
echo "$(minikube ip) registry.minikube" | sudo tee -a /etc/hosts

# Crear namespaces de desarrollo
kubectl create namespace development
kubectl create namespace testing
kubectl create namespace monitoring

# Configurar RBAC para desarrollo
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["apps", "extensions"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["networking.k8s.io"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developer-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: developer
subjects:
- kind: User
  name: developer
  apiGroup: rbac.authorization.k8s.io
EOF

echo "✅ Cluster de desarrollo listo"
```

### 2. Configurar Registry Local

```bash
# Configurar registry local para desarrollo
eval $(minikube docker-env)

# Test del registry
docker run --rm -it alpine:latest /bin/sh -c "echo 'Registry funcionando'"
```

### 3. Instalar Herramientas de Desarrollo

```bash
#!/bin/bash
# install-dev-tools.sh

# Instalar Skaffold
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
sudo install skaffold /usr/local/bin/

# Instalar Tilt
curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | bash

# Instalar Telepresence
sudo curl -fL https://app.getambassador.io/download/tel2oss/releases/download/v2.15.1/telepresence-linux-amd64 \
  -o /usr/local/bin/telepresence && sudo chmod a+x /usr/local/bin/telepresence

# Instalar k9s
curl -sS https://webi.sh/k9s | sh

echo "✅ Herramientas de desarrollo instaladas"
```

---

## Componentes del Entorno

### 1. Stack de Base de Datos

#### PostgreSQL para Desarrollo
```yaml
# postgres-dev.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-dev
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres-dev
  template:
    metadata:
      labels:
        app: postgres-dev
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_DB
          value: "devdb"
        - name: POSTGRES_USER
          value: "developer"
        - name: POSTGRES_PASSWORD
          value: "devpass123"
        - name: PGDATA
          value: "/var/lib/postgresql/data/pgdata"
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: development
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: development
spec:
  selector:
    app: postgres-dev
  ports:
  - port: 5432
    targetPort: 5432
  type: ClusterIP
```

#### Redis para Cache
```yaml
# redis-dev.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-dev
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis-dev
  template:
    metadata:
      labels:
        app: redis-dev
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  namespace: development
spec:
  selector:
    app: redis-dev
  ports:
  - port: 6379
    targetPort: 6379
```

### 2. Message Queue

#### RabbitMQ
```yaml
# rabbitmq-dev.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq-dev
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rabbitmq-dev
  template:
    metadata:
      labels:
        app: rabbitmq-dev
    spec:
      containers:
      - name: rabbitmq
        image: rabbitmq:3-management-alpine
        env:
        - name: RABBITMQ_DEFAULT_USER
          value: "developer"
        - name: RABBITMQ_DEFAULT_PASS
          value: "devpass123"
        ports:
        - containerPort: 5672
        - containerPort: 15672
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "400m"
---
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq-service
  namespace: development
spec:
  selector:
    app: rabbitmq-dev
  ports:
  - name: amqp
    port: 5672
    targetPort: 5672
  - name: management
    port: 15672
    targetPort: 15672
  type: ClusterIP
```

### 3. Herramientas de Desarrollo

#### Mailhog para Testing de Email
```yaml
# mailhog-dev.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mailhog-dev
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mailhog-dev
  template:
    metadata:
      labels:
        app: mailhog-dev
    spec:
      containers:
      - name: mailhog
        image: mailhog/mailhog:latest
        ports:
        - containerPort: 1025  # SMTP
        - containerPort: 8025  # Web UI
---
apiVersion: v1
kind: Service
metadata:
  name: mailhog-service
  namespace: development
spec:
  selector:
    app: mailhog-dev
  ports:
  - name: smtp
    port: 1025
    targetPort: 1025
  - name: web
    port: 8025
    targetPort: 8025
  type: NodePort
```

#### MinIO para Object Storage
```yaml
# minio-dev.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio-dev
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio-dev
  template:
    metadata:
      labels:
        app: minio-dev
    spec:
      containers:
      - name: minio
        image: minio/minio:latest
        args:
        - server
        - /data
        - --console-address
        - ":9001"
        env:
        - name: MINIO_ROOT_USER
          value: "developer"
        - name: MINIO_ROOT_PASSWORD
          value: "devpass123"
        ports:
        - containerPort: 9000
        - containerPort: 9001
        volumeMounts:
        - name: minio-storage
          mountPath: /data
      volumes:
      - name: minio-storage
        persistentVolumeClaim:
          claimName: minio-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-pvc
  namespace: development
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: minio-service
  namespace: development
spec:
  selector:
    app: minio-dev
  ports:
  - name: api
    port: 9000
    targetPort: 9000
  - name: console
    port: 9001
    targetPort: 9001
  type: NodePort
```

---

## Configuraciones por Herramienta

### 1. Skaffold para Desarrollo Iterativo

#### skaffold.yaml Base
```yaml
# skaffold.yaml
apiVersion: skaffold/v4beta7
kind: Config
metadata:
  name: dev-environment
build:
  local:
    push: false
  artifacts:
  - image: myapp
    docker:
      dockerfile: Dockerfile.dev
    sync:
      manual:
      - src: "src/**/*.js"
        dest: /app/src
      - src: "src/**/*.ts"
        dest: /app/src
      - src: "public/**/*"
        dest: /app/public

deploy:
  kubectl:
    manifests:
    - kubernetes-config/*.yaml

portForward:
- resourceType: service
  resourceName: myapp-service
  port: 3000
  localPort: 3000
- resourceType: service
  resourceName: postgres-service
  port: 5432
  localPort: 5432

profiles:
- name: debug
  patches:
  - op: add
    path: /build/artifacts/0/docker/buildArgs
    value:
      NODE_ENV: development
  - op: replace
    path: /deploy/kubectl/flags/global
    value: ["--namespace=development"]
```

#### Dockerfile para Desarrollo
```dockerfile
# Dockerfile.dev
FROM node:18-alpine

WORKDIR /app

# Install nodemon for hot reload
RUN npm install -g nodemon

# Copy package files
COPY package*.json ./
RUN npm install

# Copy source code
COPY . .

# Expose port
EXPOSE 3000

# Development command with hot reload
CMD ["nodemon", "--watch", "src", "--ext", "js,ts,json", "src/index.js"]
```

### 2. Tilt para Orquestación Local

#### Tiltfile
```python
# Tiltfile

# Configuración de servicios base
load('ext://helm_resource', 'helm_resource')

# Build de la aplicación principal
docker_build(
    'myapp',
    '.',
    dockerfile='Dockerfile.dev',
    live_update=[
        sync('./src', '/app/src'),
        sync('./public', '/app/public'),
        run('npm install', trigger=['./package.json', './package-lock.json'])
    ]
)

# Desplegar aplicación
k8s_yaml('kubernetes-config/app.yaml')
k8s_resource('myapp', port_forwards='3000:3000')

# Servicios de base de datos
k8s_yaml('kubernetes-config/postgres-dev.yaml')
k8s_resource('postgres-dev', port_forwards='5432:5432')

k8s_yaml('kubernetes-config/redis-dev.yaml')
k8s_resource('redis-dev', port_forwards='6379:6379')

# Herramientas de desarrollo
k8s_yaml('kubernetes-config/mailhog-dev.yaml')
k8s_resource('mailhog-dev', port_forwards=['1025:1025', '8025:8025'])

# Script para inicializar datos de prueba
local_resource(
    'setup-test-data',
    'scripts/setup-test-data.sh',
    deps=['scripts/setup-test-data.sh']
)

# Watch para cambios en configuración
watch_file('skaffold.yaml')
watch_file('Tiltfile')
```

### 3. Telepresence para Debugging Remoto

#### Configuración de Telepresence
```yaml
# telepresence.yaml
apiVersion: getambassador.io/v3alpha1
kind: Module
metadata:
  name: ambassador
spec:
  config:
    resolver: kubernetes-service
    load_balancer:
      policy: round_robin
```

#### Scripts de Debugging
```bash
#!/bin/bash
# debug-remote.sh

echo "🔍 Iniciando debugging remoto con Telepresence..."

# Conectar a cluster
telepresence connect

# Intercept del servicio
telepresence intercept myapp-service \
  --port 3000:3000 \
  --env-file .env.telepresence

echo "✅ Interceptando tráfico del servicio myapp-service"
echo "🚀 Ejecutar aplicación localmente en puerto 3000"

# Para finalizar
# telepresence leave myapp-service
# telepresence quit
```

---

## Workflows de Desarrollo

### 1. Desarrollo con Hot Reload

#### Configuración de Aplicación Node.js
```json
{
  "name": "myapp-dev",
  "scripts": {
    "dev": "nodemon --watch src --ext js,ts,json src/index.js",
    "dev:debug": "nodemon --inspect=0.0.0.0:9229 --watch src src/index.js",
    "test": "jest --watch",
    "test:integration": "jest --config jest.integration.config.js"
  },
  "devDependencies": {
    "nodemon": "^3.0.0",
    "jest": "^29.0.0"
  }
}
```

#### ConfigMap para Variables de Desarrollo
```yaml
# dev-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dev-config
  namespace: development
data:
  NODE_ENV: "development"
  LOG_LEVEL: "debug"
  DATABASE_URL: "postgresql://developer:devpass123@postgres-service:5432/devdb"
  REDIS_URL: "redis://redis-service:6379"
  RABBITMQ_URL: "amqp://developer:devpass123@rabbitmq-service:5672"
  SMTP_HOST: "mailhog-service"
  SMTP_PORT: "1025"
  S3_ENDPOINT: "http://minio-service:9000"
  S3_ACCESS_KEY: "developer"
  S3_SECRET_KEY: "devpass123"
```

### 2. Workflow con Git Hooks

#### Pre-commit Hook
```bash
#!/bin/sh
# .git/hooks/pre-commit

echo "🔍 Ejecutando pre-commit checks..."

# Lint código
npm run lint
if [ $? -ne 0 ]; then
  echo "❌ Lint falló"
  exit 1
fi

# Tests unitarios
npm test -- --passWithNoTests
if [ $? -ne 0 ]; then
  echo "❌ Tests unitarios fallaron"
  exit 1
fi

# Validar YAML de Kubernetes
for file in kubernetes-config/*.yaml; do
  kubectl --dry-run=client --validate=true apply -f "$file"
  if [ $? -ne 0 ]; then
    echo "❌ YAML inválido: $file"
    exit 1
  fi
done

echo "✅ Pre-commit checks pasaron"
```

### 3. Desarrollo con Feature Branches

#### Script de Feature Branch
```bash
#!/bin/bash
# feature-branch.sh

FEATURE_NAME=$1

if [ -z "$FEATURE_NAME" ]; then
  echo "❌ Uso: ./feature-branch.sh <nombre-feature>"
  exit 1
fi

echo "🌟 Creando entorno para feature: $FEATURE_NAME"

# Crear namespace para la feature
kubectl create namespace "feature-$FEATURE_NAME"

# Copiar secrets básicos
kubectl get secret dev-secrets -n development -o yaml | \
  sed "s/namespace: development/namespace: feature-$FEATURE_NAME/" | \
  kubectl apply -f -

# Desplegar servicios base
kubectl apply -f kubernetes-config/postgres-dev.yaml -n "feature-$FEATURE_NAME"
kubectl apply -f kubernetes-config/redis-dev.yaml -n "feature-$FEATURE_NAME"

# Configurar Skaffold para feature
cat > skaffold-feature.yaml <<EOF
apiVersion: skaffold/v4beta7
kind: Config
metadata:
  name: feature-$FEATURE_NAME
build:
  local:
    push: false
  artifacts:
  - image: myapp-$FEATURE_NAME
    docker:
      dockerfile: Dockerfile.dev
deploy:
  kubectl:
    manifests:
    - kubernetes-config/*.yaml
    flags:
      global: ["--namespace=feature-$FEATURE_NAME"]
portForward:
- resourceType: service
  resourceName: myapp-service
  port: 3000
  localPort: 3001
EOF

echo "✅ Entorno de feature listo"
echo "🚀 Usar: skaffold dev -f skaffold-feature.yaml"
```

---

## Hot Reload y Live Development

### 1. Configuración de Live Sync

#### Skaffold File Sync
```yaml
# En skaffold.yaml
build:
  artifacts:
  - image: myapp
    sync:
      manual:
      - src: "src/**/*.js"
        dest: /app/src
        strip: ""
      - src: "src/**/*.ts"
        dest: /app/src
        strip: ""
      - src: "package.json"
        dest: /app/package.json
      infer:
      - "**/*.html"
      - "**/*.css"
      - "**/*.png"
      - "**/*.jpg"
```

#### Dockerfile Optimizado para Desarrollo
```dockerfile
# Dockerfile.dev con layers optimizadas
FROM node:18-alpine

WORKDIR /app

# Layer de dependencias (cambia poco)
COPY package*.json ./
RUN npm ci --include=dev

# Layer de herramientas globales
RUN npm install -g nodemon ts-node

# Layer de código fuente (cambia frecuentemente)
COPY . .

# Health check para desarrollo
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

EXPOSE 3000 9229

# Comando con debugging habilitado
CMD ["nodemon", "--inspect=0.0.0.0:9229", "--watch", "src", "src/index.js"]
```

### 2. Live Reload para Frontend

#### Webpack Dev Server Config
```javascript
// webpack.dev.js
const path = require('path');

module.exports = {
  mode: 'development',
  devtool: 'inline-source-map',
  devServer: {
    static: './dist',
    hot: true,
    host: '0.0.0.0',
    port: 3000,
    allowedHosts: 'all',
    watchFiles: ['src/**/*'],
    client: {
      webSocketURL: 'ws://localhost:3000/ws'
    }
  },
  watch: true,
  watchOptions: {
    aggregateTimeout: 300,
    poll: 1000,
    ignored: /node_modules/
  }
};
```

### 3. Database Schema Migration Live

#### Desarrollo con Prisma
```bash
#!/bin/bash
# migrate-dev.sh

echo "🔄 Aplicando migraciones de desarrollo..."

# Forward del puerto de base de datos
kubectl port-forward service/postgres-service 5432:5432 &
PORT_FORWARD_PID=$!

# Esperar conexión
sleep 2

# Aplicar migraciones
npx prisma migrate dev --name dev-migration

# Generar cliente
npx prisma generate

# Seedear datos de desarrollo
npx prisma db seed

# Cerrar port-forward
kill $PORT_FORWARD_PID

echo "✅ Base de datos actualizada"
```

---

## Debugging en Kubernetes

### 1. Debugging de Aplicaciones Node.js

#### Configuración de Debug
```yaml
# app-debug.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-debug
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp-debug
  template:
    metadata:
      labels:
        app: myapp-debug
    spec:
      containers:
      - name: app
        image: myapp:debug
        ports:
        - containerPort: 3000
        - containerPort: 9229  # Debug port
        env:
        - name: NODE_ENV
          value: "development"
        - name: DEBUG
          value: "*"
        command: ["node", "--inspect=0.0.0.0:9229", "src/index.js"]
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-debug-service
  namespace: development
spec:
  selector:
    app: myapp-debug
  ports:
  - name: http
    port: 3000
    targetPort: 3000
  - name: debug
    port: 9229
    targetPort: 9229
  type: NodePort
```

#### VS Code Launch Configuration
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug Kubernetes App",
      "type": "node",
      "request": "attach",
      "port": 9229,
      "address": "localhost",
      "localRoot": "${workspaceFolder}/src",
      "remoteRoot": "/app/src",
      "sourceMaps": true,
      "restart": true,
      "timeout": 60000
    }
  ]
}
```

### 2. Debugging con Telepresence

```bash
#!/bin/bash
# debug-with-telepresence.sh

echo "🔍 Configurando debugging con Telepresence..."

# Conectar a cluster
telepresence connect

# Crear intercept
telepresence intercept myapp-service \
  --port 3000:3000 \
  --port 9229:9229 \
  --env-file .env.telepresence

echo "✅ Intercept activo"
echo "🚀 Ejecutar aplicación local con debugging:"
echo "node --inspect=0.0.0.0:9229 src/index.js"
```

### 3. Debug de Base de Datos

#### pgAdmin para PostgreSQL
```yaml
# pgadmin-dev.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pgadmin-dev
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pgadmin-dev
  template:
    metadata:
      labels:
        app: pgadmin-dev
    spec:
      containers:
      - name: pgadmin
        image: dpage/pgadmin4:latest
        env:
        - name: PGADMIN_DEFAULT_EMAIL
          value: "dev@company.com"
        - name: PGADMIN_DEFAULT_PASSWORD
          value: "devpass123"
        - name: PGADMIN_CONFIG_SERVER_MODE
          value: "False"
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: pgadmin-service
  namespace: development
spec:
  selector:
    app: pgadmin-dev
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
```

---

## Testing Local

### 1. Tests Unitarios en Paralelo

#### Jest Configuration
```javascript
// jest.config.js
module.exports = {
  testEnvironment: 'node',
  maxWorkers: 4,
  testMatch: ['**/__tests__/**/*.test.js'],
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/**/*.test.js',
    '!src/test-utils/**'
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },
  setupFilesAfterEnv: ['<rootDir>/src/test-utils/setup.js']
};
```

### 2. Tests de Integración

#### Test Database Setup
```bash
#!/bin/bash
# setup-test-db.sh

# Crear base de datos de test
kubectl exec -it postgres-dev-pod -- createdb -U developer testdb

# Ejecutar migraciones
DATABASE_URL="postgresql://developer:devpass123@localhost:5432/testdb" \
  npx prisma migrate deploy

# Seedear datos de prueba
DATABASE_URL="postgresql://developer:devpass123@localhost:5432/testdb" \
  npm run seed:test
```

#### Integration Test Example
```javascript
// tests/integration/api.test.js
const request = require('supertest');
const app = require('../../src/app');

describe('API Integration Tests', () => {
  beforeAll(async () => {
    // Setup test database
    await setupTestDB();
  });

  afterAll(async () => {
    await cleanupTestDB();
  });

  describe('POST /api/users', () => {
    it('should create a new user', async () => {
      const userData = {
        name: 'Test User',
        email: 'test@example.com'
      };

      const response = await request(app)
        .post('/api/users')
        .send(userData)
        .expect(201);

      expect(response.body).toHaveProperty('id');
      expect(response.body.name).toBe(userData.name);
    });
  });
});
```

### 3. End-to-End Testing

#### Cypress en Kubernetes
```yaml
# cypress-runner.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: e2e-tests
  namespace: development
spec:
  template:
    spec:
      containers:
      - name: cypress
        image: cypress/included:latest
        env:
        - name: CYPRESS_baseUrl
          value: "http://myapp-service:3000"
        - name: CYPRESS_VIDEO
          value: "false"
        - name: CYPRESS_SCREENSHOT_ON_FAILURE
          value: "true"
        volumeMounts:
        - name: cypress-tests
          mountPath: /e2e
        workingDir: /e2e
        command: ["cypress", "run", "--browser", "chrome"]
      volumes:
      - name: cypress-tests
        configMap:
          name: cypress-tests
      restartPolicy: Never
  backoffLimit: 3
```

---

## Monitoreo y Observabilidad

### 1. Logging con ELK Stack

#### Filebeat Configuration
```yaml
# filebeat-dev.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: filebeat-dev
  namespace: development
spec:
  selector:
    matchLabels:
      app: filebeat-dev
  template:
    metadata:
      labels:
        app: filebeat-dev
    spec:
      containers:
      - name: filebeat
        image: docker.elastic.co/beats/filebeat:8.8.0
        env:
        - name: ELASTICSEARCH_HOST
          value: "elasticsearch-service"
        - name: KIBANA_HOST
          value: "kibana-service"
        volumeMounts:
        - name: config
          mountPath: /usr/share/filebeat/filebeat.yml
          subPath: filebeat.yml
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: varlog
          mountPath: /var/log
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: filebeat-config
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: varlog
        hostPath:
          path: /var/log
```

### 2. Métricas con Prometheus

#### ServiceMonitor Configuration
```yaml
# servicemonitor-dev.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp-metrics
  namespace: development
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### 3. Tracing con Jaeger

#### Jaeger All-in-One
```yaml
# jaeger-dev.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger-dev
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger-dev
  template:
    metadata:
      labels:
        app: jaeger-dev
    spec:
      containers:
      - name: jaeger
        image: jaegertracing/all-in-one:latest
        env:
        - name: COLLECTOR_OTLP_ENABLED
          value: "true"
        ports:
        - containerPort: 16686  # UI
        - containerPort: 14268  # HTTP collector
        - containerPort: 4317   # OTLP gRPC
        - containerPort: 4318   # OTLP HTTP
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-service
  namespace: development
spec:
  selector:
    app: jaeger-dev
  ports:
  - name: ui
    port: 16686
    targetPort: 16686
  - name: collector
    port: 14268
    targetPort: 14268
  - name: grpc
    port: 4317
    targetPort: 4317
  - name: http
    port: 4318
    targetPort: 4318
  type: NodePort
```

---

## Troubleshooting

### 1. Comandos de Diagnóstico

```bash
#!/bin/bash
# diagnose-dev-env.sh

echo "🔍 Diagnósticando entorno de desarrollo..."

# Estado del cluster
echo "📊 Estado del cluster:"
kubectl cluster-info
kubectl get nodes -o wide

# Estado de los pods
echo "🏗️ Estado de los pods de desarrollo:"
kubectl get pods -n development -o wide

# Recursos utilizados
echo "📈 Uso de recursos:"
kubectl top nodes
kubectl top pods -n development

# Eventos recientes
echo "📰 Eventos recientes:"
kubectl get events -n development --sort-by='.lastTimestamp'

# Estado de los servicios
echo "🌐 Estado de servicios:"
kubectl get services -n development

# Logs de aplicación
echo "📋 Logs recientes de la aplicación:"
kubectl logs -l app=myapp -n development --tail=20

# Conectividad de red
echo "🔗 Test de conectividad:"
kubectl run debug-pod --image=busybox -it --rm --restart=Never -- /bin/sh -c "
  nslookup postgres-service.development.svc.cluster.local
  nslookup redis-service.development.svc.cluster.local
  wget -qO- http://myapp-service.development.svc.cluster.local:3000/health
"
```

### 2. Debugging de Red

```bash
# Debug de conectividad
kubectl run netshoot --image=nicolaka/netshoot -it --rm --restart=Never -- /bin/bash

# Dentro del pod netshoot:
# dig postgres-service.development.svc.cluster.local
# curl -v http://myapp-service:3000/health
# ping redis-service
# telnet rabbitmq-service 5672
```

### 3. Troubleshooting de Persistencia

```bash
#!/bin/bash
# check-persistence.sh

echo "💾 Verificando volúmenes persistentes..."

# Lista PVs y PVCs
kubectl get pv,pvc -n development

# Verificar montajes
for pod in $(kubectl get pods -n development -o name); do
  echo "📁 Volúmenes en $pod:"
  kubectl describe $pod -n development | grep -A 10 "Volumes:"
done

# Test de escritura en PostgreSQL
kubectl exec -it postgres-dev-pod -n development -- /bin/bash -c "
  echo 'CREATE TABLE test_persistence (id SERIAL PRIMARY KEY, data TEXT);' | psql -U developer -d devdb
  echo 'INSERT INTO test_persistence (data) VALUES (\"persistence test\");' | psql -U developer -d devdb
  echo 'SELECT * FROM test_persistence;' | psql -U developer -d devdb
"
```

---

## Mejores Prácticas

### 1. Gestión de Recursos

#### Resource Quotas para Desarrollo
```yaml
# dev-resource-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: development
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
    services: "20"
    pods: "30"
```

#### LimitRange para Pods
```yaml
# dev-limit-range.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limits
  namespace: development
spec:
  limits:
  - default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    type: Container
```

### 2. Seguridad en Desarrollo

#### NetworkPolicy para Desarrollo
```yaml
# dev-network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dev-network-policy
  namespace: development
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: development
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: development
  - to: {}  # Allow external traffic for development
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
```

### 3. Automatización

#### Makefile para Tareas Comunes
```makefile
# Makefile
.PHONY: dev-start dev-stop dev-restart dev-logs dev-test dev-clean

# Iniciar entorno de desarrollo
dev-start:
	@echo "🚀 Iniciando entorno de desarrollo..."
	minikube start --driver=docker --cpus=4 --memory=8192
	kubectl apply -f kubernetes-config/
	skaffold dev

# Parar entorno
dev-stop:
	@echo "🛑 Parando entorno de desarrollo..."
	skaffold delete
	minikube stop

# Reiniciar aplicación
dev-restart:
	@echo "🔄 Reiniciando aplicación..."
	kubectl rollout restart deployment/myapp -n development

# Ver logs
dev-logs:
	@echo "📋 Logs de la aplicación:"
	kubectl logs -f -l app=myapp -n development

# Ejecutar tests
dev-test:
	@echo "🧪 Ejecutando tests..."
	npm test
	kubectl apply -f kubernetes-config/cypress-runner.yaml

# Limpiar recursos
dev-clean:
	@echo "🧹 Limpiando recursos..."
	kubectl delete namespace development --ignore-not-found
	docker system prune -f
	minikube delete
```

### 4. Documentación Viva

#### README para Desarrolladores
```markdown
# Guía Rápida de Desarrollo

## Setup Inicial
```bash
make dev-start
```

## Desarrollo Diario
```bash
# Iniciar con hot reload
skaffold dev

# Ejecutar tests
make dev-test

# Ver logs
make dev-logs
```

## URLs Útiles
- Aplicación: http://localhost:3000
- pgAdmin: http://localhost:8080
- Mailhog: http://localhost:8025
- RabbitMQ Management: http://localhost:15672
```

Con esta configuración completa, tendrás un entorno de desarrollo robusto que replica las condiciones de producción mientras mantiene la eficiencia y velocidad necesarias para el desarrollo diario.

El entorno incluye todas las herramientas necesarias para desarrollo iterativo, debugging, testing y monitoreo, proporcionando una experiencia de desarrollo moderna y eficiente en Kubernetes.
