# Casos de Uso para Entorno de Desarrollo

Este documento presenta casos de uso prácticos y configuraciones específicas para utilizar Kubernetes en entornos de desarrollo local y distribuido.

## Tabla de Contenidos

1. [Hot Reload Development](#hot-reload-development)
2. [Multi-Service Development](#multi-service-development)
3. [Database Development Environment](#database-development-environment)
4. [Microservices Local Testing](#microservices-local-testing)
5. [Frontend-Backend Integration](#frontend-backend-integration)
6. [API Development and Testing](#api-development-and-testing)
7. [Development with External Dependencies](#development-with-external-dependencies)
8. [Team Collaboration Environment](#team-collaboration-environment)
9. [Development Debugging](#development-debugging)
10. [Performance Testing in Development](#performance-testing-in-development)

---

## Hot Reload Development

### Caso de Uso: Desarrollo con Recarga Automática

**Escenario**: Un desarrollador trabajando en una aplicación Node.js necesita ver cambios en tiempo real sin reconstruir contenedores constantemente.

#### Configuración con Skaffold

```yaml
# skaffold.yaml
apiVersion: skaffold/v4beta6
kind: Config
metadata:
  name: hot-reload-dev
build:
  artifacts:
  - image: my-node-app
    context: .
    docker:
      dockerfile: Dockerfile.dev
    sync:
      manual:
      - src: "src/**/*.js"
        dest: /app/src
      - src: "package.json"
        dest: /app
  local:
    push: false
deploy:
  kubectl:
    manifests:
    - k8s-dev/*.yaml
portForward:
- resourceType: service
  resourceName: node-app-service
  port: 3000
  localPort: 3000
```

#### Dockerfile para Desarrollo

```dockerfile
# Dockerfile.dev
FROM node:18-alpine

WORKDIR /app

# Instalar nodemon para hot reload
RUN npm install -g nodemon

# Copiar package.json
COPY package*.json ./
RUN npm install

# Copiar código fuente
COPY src/ ./src/

# Exponer puerto
EXPOSE 3000

# Comando para desarrollo con hot reload
CMD ["nodemon", "--watch", "src", "--ext", "js,json", "src/app.js"]
```

#### Configuración de Kubernetes para Desarrollo

```yaml
# k8s-dev/development.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: node-app-dev
  labels:
    app: node-app
    environment: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: node-app
      environment: development
  template:
    metadata:
      labels:
        app: node-app
        environment: development
    spec:
      containers:
      - name: node-app
        image: my-node-app
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "development"
        - name: DEBUG
          value: "*"
        - name: DB_HOST
          value: "postgres-dev"
        volumeMounts:
        - name: source-code
          mountPath: /app/src
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: source-code
        hostPath:
          path: /path/to/local/src
          type: Directory
---
apiVersion: v1
kind: Service
metadata:
  name: node-app-service
  labels:
    app: node-app
    environment: development
spec:
  selector:
    app: node-app
    environment: development
  ports:
  - port: 3000
    targetPort: 3000
    name: http
  type: ClusterIP
```

#### Script de Desarrollo

```bash
#!/bin/bash
# dev-setup.sh

set -e

echo "🚀 Configurando entorno de desarrollo con hot reload..."

# Verificar dependencias
command -v skaffold >/dev/null 2>&1 || { echo "❌ Skaffold requerido"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl requerido"; exit 1; }

# Configurar namespace de desarrollo
kubectl create namespace development --dry-run=client -o yaml | kubectl apply -f -
kubectl config set-context --current --namespace=development

# Desplegar dependencias (base de datos)
kubectl apply -f k8s-dev/postgres-dev.yaml

# Esperar a que postgres esté listo
kubectl wait --for=condition=ready pod -l app=postgres-dev --timeout=300s

# Inicializar base de datos
kubectl exec -it deployment/postgres-dev -- psql -U postgres -c "CREATE DATABASE devdb;"

# Iniciar desarrollo con hot reload
echo "🔥 Iniciando hot reload development..."
skaffold dev --cleanup=false --port-forward=true

# Cuando se interrumpa, limpiar recursos
trap 'skaffold delete' EXIT
```

---

## Multi-Service Development

### Caso de Uso: Desarrollo de Microservicios Interdependientes

**Escenario**: Un equipo desarrolla múltiples microservicios que necesitan comunicarse entre sí durante el desarrollo.

#### Docker Compose para Desarrollo

```yaml
# docker-compose.dev.yaml
version: '3.8'
services:
  user-service:
    build:
      context: ./user-service
      dockerfile: Dockerfile.dev
    ports:
    - "3001:3000"
    environment:
    - NODE_ENV=development
    - DB_HOST=postgres
    - REDIS_HOST=redis
    volumes:
    - ./user-service/src:/app/src
    depends_on:
    - postgres
    - redis
    
  order-service:
    build:
      context: ./order-service
      dockerfile: Dockerfile.dev
    ports:
    - "3002:3000"
    environment:
    - NODE_ENV=development
    - DB_HOST=postgres
    - USER_SERVICE_URL=http://user-service:3000
    volumes:
    - ./order-service/src:/app/src
    depends_on:
    - postgres
    - user-service
    
  notification-service:
    build:
      context: ./notification-service
      dockerfile: Dockerfile.dev
    ports:
    - "3003:3000"
    environment:
    - NODE_ENV=development
    - REDIS_HOST=redis
    - ORDER_SERVICE_URL=http://order-service:3000
    volumes:
    - ./notification-service/src:/app/src
    depends_on:
    - redis
    - order-service
    
  postgres:
    image: postgres:15-alpine
    environment:
    - POSTGRES_USER=devuser
    - POSTGRES_PASSWORD=devpass
    - POSTGRES_DB=devdb
    ports:
    - "5432:5432"
    volumes:
    - postgres_data:/var/lib/postgresql/data
    - ./db/init.sql:/docker-entrypoint-initdb.d/init.sql
    
  redis:
    image: redis:7-alpine
    ports:
    - "6379:6379"
    volumes:
    - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

#### Kubernetes Multi-Service Setup

```yaml
# k8s-dev/multi-service-dev.yaml
# Namespace para desarrollo
apiVersion: v1
kind: Namespace
metadata:
  name: multi-service-dev
---
# ConfigMap con configuración compartida
apiVersion: v1
kind: ConfigMap
metadata:
  name: dev-config
  namespace: multi-service-dev
data:
  NODE_ENV: "development"
  LOG_LEVEL: "debug"
  DB_HOST: "postgres-dev"
  REDIS_HOST: "redis-dev"
  USER_SERVICE_URL: "http://user-service:3000"
  ORDER_SERVICE_URL: "http://order-service:3000"
  NOTIFICATION_SERVICE_URL: "http://notification-service:3000"
---
# PostgreSQL para desarrollo
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-dev
  namespace: multi-service-dev
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
        - name: POSTGRES_USER
          value: "devuser"
        - name: POSTGRES_PASSWORD
          value: "devpass"
        - name: POSTGRES_DB
          value: "devdb"
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        - name: init-script
          mountPath: /docker-entrypoint-initdb.d
      volumes:
      - name: postgres-storage
        emptyDir: {}
      - name: init-script
        configMap:
          name: postgres-init
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-dev
  namespace: multi-service-dev
spec:
  selector:
    app: postgres-dev
  ports:
  - port: 5432
    targetPort: 5432
---
# Redis para desarrollo
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-dev
  namespace: multi-service-dev
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
        volumeMounts:
        - name: redis-storage
          mountPath: /data
      volumes:
      - name: redis-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: redis-dev
  namespace: multi-service-dev
spec:
  selector:
    app: redis-dev
  ports:
  - port: 6379
    targetPort: 6379
---
# User Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: multi-service-dev
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
        image: user-service:dev
        imagePullPolicy: Never
        ports:
        - containerPort: 3000
        envFrom:
        - configMapRef:
            name: dev-config
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: multi-service-dev
spec:
  selector:
    app: user-service
  ports:
  - port: 3000
    targetPort: 3000
---
# Order Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: multi-service-dev
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
        image: order-service:dev
        imagePullPolicy: Never
        ports:
        - containerPort: 3000
        envFrom:
        - configMapRef:
            name: dev-config
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: multi-service-dev
spec:
  selector:
    app: order-service
  ports:
  - port: 3000
    targetPort: 3000
```

#### Telepresence Development Workflow

```bash
#!/bin/bash
# telepresence-dev.sh

set -e

echo "🔗 Configurando Telepresence para desarrollo multi-servicio..."

# Instalar Telepresence si no está instalado
if ! command -v telepresence &> /dev/null; then
    echo "Instalando Telepresence..."
    sudo curl -fL https://app.getambassador.io/download/tel2/linux/amd64/latest/telepresence -o /usr/local/bin/telepresence
    sudo chmod a+x /usr/local/bin/telepresence
fi

# Conectar a cluster
telepresence connect

# Configurar namespace
kubectl config set-context --current --namespace=multi-service-dev

# Interceptar servicio para desarrollo local
echo "🎯 Interceptando user-service para desarrollo local..."
telepresence intercept user-service --port 3000:3000 --env-file ./user-service/.env

# En otra terminal, ejecutar el servicio localmente
echo "💻 Ejecuta en otra terminal:"
echo "cd user-service && npm run dev"

# Cuando termine, limpiar
trap 'telepresence leave user-service; telepresence quit' EXIT

echo "✅ Telepresence configurado. El tráfico a user-service se redirigirá a tu máquina local."
echo "Presiona Ctrl+C para terminar la intercepción."

# Mantener el script ejecutando
while true; do
    sleep 5
done
```

---

## Database Development Environment

### Caso de Uso: Entorno de Base de Datos para Desarrollo

**Escenario**: Configurar múltiples bases de datos con datos de prueba para desarrollo de aplicaciones.

#### Multi-Database Setup

```yaml
# k8s-dev/database-dev.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: database-dev
---
# PostgreSQL principal
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-main
  namespace: database-dev
spec:
  serviceName: postgres-main
  replicas: 1
  selector:
    matchLabels:
      app: postgres-main
  template:
    metadata:
      labels:
        app: postgres-main
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_USER
          value: "devuser"
        - name: POSTGRES_PASSWORD
          value: "devpass123"
        - name: POSTGRES_DB
          value: "maindb"
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        - name: init-scripts
          mountPath: /docker-entrypoint-initdb.d
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "500m"
      volumes:
      - name: init-scripts
        configMap:
          name: postgres-init-scripts
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-main
  namespace: database-dev
spec:
  selector:
    app: postgres-main
  ports:
  - port: 5432
    targetPort: 5432
  type: ClusterIP
---
# MongoDB para desarrollo
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb-dev
  namespace: database-dev
spec:
  serviceName: mongodb-dev
  replicas: 1
  selector:
    matchLabels:
      app: mongodb-dev
  template:
    metadata:
      labels:
        app: mongodb-dev
    spec:
      containers:
      - name: mongodb
        image: mongo:7
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          value: "devuser"
        - name: MONGO_INITDB_ROOT_PASSWORD
          value: "devpass123"
        - name: MONGO_INITDB_DATABASE
          value: "devdb"
        ports:
        - containerPort: 27017
        volumeMounts:
        - name: mongodb-storage
          mountPath: /data/db
        - name: mongodb-init
          mountPath: /docker-entrypoint-initdb.d
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "500m"
      volumes:
      - name: mongodb-init
        configMap:
          name: mongodb-init-scripts
  volumeClaimTemplates:
  - metadata:
      name: mongodb-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb-dev
  namespace: database-dev
spec:
  selector:
    app: mongodb-dev
  ports:
  - port: 27017
    targetPort: 27017
---
# Redis para cache y sessions
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-dev
  namespace: database-dev
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
        command:
        - redis-server
        - /usr/local/etc/redis/redis.conf
        ports:
        - containerPort: 6379
        volumeMounts:
        - name: redis-config
          mountPath: /usr/local/etc/redis
        - name: redis-data
          mountPath: /data
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
      volumes:
      - name: redis-config
        configMap:
          name: redis-config
      - name: redis-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: redis-dev
  namespace: database-dev
spec:
  selector:
    app: redis-dev
  ports:
  - port: 6379
    targetPort: 6379
---
# Elasticsearch para búsquedas
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch-dev
  namespace: database-dev
spec:
  serviceName: elasticsearch-dev
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch-dev
  template:
    metadata:
      labels:
        app: elasticsearch-dev
    spec:
      containers:
      - name: elasticsearch
        image: elasticsearch:8.8.0
        env:
        - name: discovery.type
          value: "single-node"
        - name: ES_JAVA_OPTS
          value: "-Xms512m -Xmx512m"
        - name: xpack.security.enabled
          value: "false"
        ports:
        - containerPort: 9200
        - containerPort: 9300
        volumeMounts:
        - name: elasticsearch-data
          mountPath: /usr/share/elasticsearch/data
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
  volumeClaimTemplates:
  - metadata:
      name: elasticsearch-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch-dev
  namespace: database-dev
spec:
  selector:
    app: elasticsearch-dev
  ports:
  - port: 9200
    targetPort: 9200
    name: http
  - port: 9300
    targetPort: 9300
    name: transport
```

#### Database Initialization Scripts

```yaml
# k8s-dev/database-init-scripts.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-init-scripts
  namespace: database-dev
data:
  01-create-schemas.sql: |
    -- Crear esquemas de base de datos
    CREATE SCHEMA IF NOT EXISTS users;
    CREATE SCHEMA IF NOT EXISTS orders;
    CREATE SCHEMA IF NOT EXISTS products;
    CREATE SCHEMA IF NOT EXISTS analytics;
    
  02-create-tables.sql: |
    -- Tabla de usuarios
    CREATE TABLE users.users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        username VARCHAR(100) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        first_name VARCHAR(100),
        last_name VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Tabla de productos
    CREATE TABLE products.products (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        price DECIMAL(10,2) NOT NULL,
        stock_quantity INTEGER DEFAULT 0,
        category VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Tabla de órdenes
    CREATE TABLE orders.orders (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users.users(id),
        total_amount DECIMAL(10,2) NOT NULL,
        status VARCHAR(50) DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    CREATE TABLE orders.order_items (
        id SERIAL PRIMARY KEY,
        order_id INTEGER REFERENCES orders.orders(id),
        product_id INTEGER REFERENCES products.products(id),
        quantity INTEGER NOT NULL,
        unit_price DECIMAL(10,2) NOT NULL,
        total_price DECIMAL(10,2) NOT NULL
    );
    
  03-insert-sample-data.sql: |
    -- Datos de ejemplo para usuarios
    INSERT INTO users.users (email, username, password_hash, first_name, last_name) VALUES
    ('john.doe@example.com', 'johndoe', '$2b$10$hashedpassword1', 'John', 'Doe'),
    ('jane.smith@example.com', 'janesmith', '$2b$10$hashedpassword2', 'Jane', 'Smith'),
    ('bob.wilson@example.com', 'bobwilson', '$2b$10$hashedpassword3', 'Bob', 'Wilson'),
    ('alice.brown@example.com', 'alicebrown', '$2b$10$hashedpassword4', 'Alice', 'Brown');
    
    -- Datos de ejemplo para productos
    INSERT INTO products.products (name, description, price, stock_quantity, category) VALUES
    ('Laptop Dell XPS 13', 'Ultrabook de alto rendimiento', 1299.99, 10, 'Electronics'),
    ('iPhone 15 Pro', 'Smartphone de última generación', 999.99, 25, 'Electronics'),
    ('Camiseta Básica', 'Camiseta de algodón 100%', 19.99, 100, 'Clothing'),
    ('Zapatillas Running', 'Zapatillas para correr profesionales', 129.99, 50, 'Sports'),
    ('Libro: Clean Code', 'Guía para escribir código limpio', 45.99, 30, 'Books');
    
    -- Datos de ejemplo para órdenes
    INSERT INTO orders.orders (user_id, total_amount, status) VALUES
    (1, 1299.99, 'completed'),
    (2, 999.99, 'shipped'),
    (3, 149.98, 'pending'),
    (4, 45.99, 'completed');
    
    INSERT INTO orders.order_items (order_id, product_id, quantity, unit_price, total_price) VALUES
    (1, 1, 1, 1299.99, 1299.99),
    (2, 2, 1, 999.99, 999.99),
    (3, 3, 2, 19.99, 39.98),
    (3, 4, 1, 129.99, 129.99),
    (4, 5, 1, 45.99, 45.99);
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mongodb-init-scripts
  namespace: database-dev
data:
  init-mongo.js: |
    // Crear colecciones y datos de ejemplo
    db = db.getSiblingDB('devdb');
    
    // Colección de usuarios
    db.users.insertMany([
      {
        username: "johndoe",
        email: "john.doe@example.com",
        profile: {
          firstName: "John",
          lastName: "Doe",
          age: 30,
          interests: ["technology", "sports", "reading"]
        },
        preferences: {
          notifications: true,
          theme: "dark",
          language: "en"
        },
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        username: "janesmith",
        email: "jane.smith@example.com",
        profile: {
          firstName: "Jane",
          lastName: "Smith",
          age: 28,
          interests: ["design", "photography", "travel"]
        },
        preferences: {
          notifications: false,
          theme: "light",
          language: "es"
        },
        createdAt: new Date(),
        updatedAt: new Date()
      }
    ]);
    
    // Colección de productos
    db.products.insertMany([
      {
        name: "Wireless Headphones",
        description: "Premium quality wireless headphones with noise cancellation",
        price: 199.99,
        category: "Electronics",
        tags: ["audio", "wireless", "premium"],
        specifications: {
          brand: "TechCorp",
          model: "WH-1000X",
          color: "Black",
          weight: "250g"
        },
        inventory: {
          stock: 50,
          warehouse: "US-EAST",
          lastRestocked: new Date()
        },
        createdAt: new Date(),
        updatedAt: new Date()
      }
    ]);
    
    // Crear índices
    db.users.createIndex({ "email": 1 }, { unique: true });
    db.users.createIndex({ "username": 1 }, { unique: true });
    db.products.createIndex({ "category": 1 });
    db.products.createIndex({ "tags": 1 });
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: database-dev
data:
  redis.conf: |
    # Redis configuration for development
    bind 0.0.0.0
    protected-mode no
    port 6379
    
    # Memory settings
    maxmemory 256mb
    maxmemory-policy allkeys-lru
    
    # Persistence
    save 900 1
    save 300 10
    save 60 10000
    
    # Logging
    loglevel notice
    
    # Development settings
    timeout 0
    tcp-keepalive 300
```

#### Database Management Script

```bash
#!/bin/bash
# manage-databases.sh

set -e

NAMESPACE="database-dev"

# Función para mostrar ayuda
show_help() {
    echo "Database Development Environment Manager"
    echo ""
    echo "Uso: $0 [COMANDO]"
    echo ""
    echo "Comandos:"
    echo "  setup       - Configurar entorno completo de bases de datos"
    echo "  reset       - Resetear todas las bases de datos con datos frescos"
    echo "  backup      - Crear backup de todas las bases de datos"
    echo "  restore     - Restaurar backup de bases de datos"
    echo "  connect     - Conectar a una base de datos específica"
    echo "  status      - Mostrar estado de todas las bases de datos"
    echo "  logs        - Mostrar logs de las bases de datos"
    echo "  cleanup     - Eliminar todo el entorno de desarrollo"
    echo ""
}

# Función para configurar el entorno
setup_environment() {
    echo "🚀 Configurando entorno de desarrollo de bases de datos..."
    
    # Crear namespace
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Aplicar ConfigMaps
    kubectl apply -f k8s-dev/database-init-scripts.yaml
    
    # Desplegar bases de datos
    kubectl apply -f k8s-dev/database-dev.yaml
    
    echo "⏳ Esperando a que las bases de datos estén listas..."
    
    # Esperar PostgreSQL
    kubectl wait --for=condition=ready pod -l app=postgres-main -n $NAMESPACE --timeout=300s
    
    # Esperar MongoDB
    kubectl wait --for=condition=ready pod -l app=mongodb-dev -n $NAMESPACE --timeout=300s
    
    # Esperar Redis
    kubectl wait --for=condition=ready pod -l app=redis-dev -n $NAMESPACE --timeout=300s
    
    # Esperar Elasticsearch
    kubectl wait --for=condition=ready pod -l app=elasticsearch-dev -n $NAMESPACE --timeout=300s
    
    echo "✅ Entorno de bases de datos configurado exitosamente"
    
    # Mostrar información de conexión
    show_connection_info
}

# Función para mostrar información de conexión
show_connection_info() {
    echo ""
    echo "📋 Información de Conexión:"
    echo ""
    echo "PostgreSQL:"
    echo "  Host: localhost (con port-forward)"
    echo "  Puerto: 5432"
    echo "  Usuario: devuser"
    echo "  Password: devpass123"
    echo "  Base de datos: maindb"
    echo "  Comando port-forward: kubectl port-forward svc/postgres-main 5432:5432 -n $NAMESPACE"
    echo ""
    echo "MongoDB:"
    echo "  Host: localhost (con port-forward)"
    echo "  Puerto: 27017"
    echo "  Usuario: devuser"
    echo "  Password: devpass123"
    echo "  Base de datos: devdb"
    echo "  Comando port-forward: kubectl port-forward svc/mongodb-dev 27017:27017 -n $NAMESPACE"
    echo ""
    echo "Redis:"
    echo "  Host: localhost (con port-forward)"
    echo "  Puerto: 6379"
    echo "  Comando port-forward: kubectl port-forward svc/redis-dev 6379:6379 -n $NAMESPACE"
    echo ""
    echo "Elasticsearch:"
    echo "  Host: localhost (con port-forward)"
    echo "  Puerto: 9200"
    echo "  Comando port-forward: kubectl port-forward svc/elasticsearch-dev 9200:9200 -n $NAMESPACE"
}

# Función para resetear bases de datos
reset_databases() {
    echo "🔄 Reseteando bases de datos con datos frescos..."
    
    # Recrear PostgreSQL pod para ejecutar init scripts
    kubectl delete pod -l app=postgres-main -n $NAMESPACE
    kubectl wait --for=condition=ready pod -l app=postgres-main -n $NAMESPACE --timeout=300s
    
    # Recrear MongoDB pod
    kubectl delete pod -l app=mongodb-dev -n $NAMESPACE
    kubectl wait --for=condition=ready pod -l app=mongodb-dev -n $NAMESPACE --timeout=300s
    
    # Limpiar Redis
    kubectl exec -n $NAMESPACE deployment/redis-dev -- redis-cli FLUSHALL
    
    echo "✅ Bases de datos reseteadas"
}

# Función para mostrar estado
show_status() {
    echo "📊 Estado de las bases de datos:"
    echo ""
    kubectl get pods -n $NAMESPACE -o wide
    echo ""
    kubectl get services -n $NAMESPACE
}

# Función para conectar a base de datos
connect_to_database() {
    echo "🔗 Opciones de conexión:"
    echo "1. PostgreSQL"
    echo "2. MongoDB"
    echo "3. Redis"
    echo "4. Elasticsearch"
    echo ""
    read -p "Selecciona una opción (1-4): " choice
    
    case $choice in
        1)
            echo "Conectando a PostgreSQL..."
            kubectl exec -it -n $NAMESPACE deployment/postgres-main -- psql -U devuser -d maindb
            ;;
        2)
            echo "Conectando a MongoDB..."
            kubectl exec -it -n $NAMESPACE deployment/mongodb-dev -- mongosh devdb -u devuser -p devpass123
            ;;
        3)
            echo "Conectando a Redis..."
            kubectl exec -it -n $NAMESPACE deployment/redis-dev -- redis-cli
            ;;
        4)
            echo "Elasticsearch está disponible en:"
            kubectl port-forward -n $NAMESPACE svc/elasticsearch-dev 9200:9200 &
            echo "http://localhost:9200"
            ;;
        *)
            echo "Opción inválida"
            ;;
    esac
}

# Procesar argumentos
case "${1:-}" in
    setup)
        setup_environment
        ;;
    reset)
        reset_databases
        ;;
    connect)
        connect_to_database
        ;;
    status)
        show_status
        ;;
    cleanup)
        echo "🧹 Eliminando entorno de desarrollo..."
        kubectl delete namespace $NAMESPACE
        echo "✅ Entorno eliminado"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_help
        ;;
    *)
        echo "Comando desconocido: $1"
        show_help
        exit 1
        ;;
esac
```

Este documento continúa con más casos de uso específicos para entornos de desarrollo, incluyendo testing de APIs, debugging, colaboración en equipo, y optimización de performance.
