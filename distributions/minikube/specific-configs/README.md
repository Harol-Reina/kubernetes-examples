# Configuraciones Específicas de Minikube

Esta carpeta contiene configuraciones y ejemplos que aprovechan características específicas de Minikube que no están disponibles en otras distribuciones de Kubernetes.

## 🎯 Contenido Específico de Minikube

### 1. Addons de Minikube

#### Dashboard de Kubernetes
```bash
# Habilitar dashboard
minikube addons enable dashboard

# Acceder al dashboard
minikube dashboard
```

#### Registry Local
```yaml
# minikube-registry.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: registry-config
data:
  enable: "true"
  port: "5000"
```

```bash
# Habilitar registry local
minikube addons enable registry

# Usar registry local en deployments
docker build -t localhost:5000/my-app:latest .
docker push localhost:5000/my-app:latest
```

### 2. Configuración de Túneles

#### Túnel para LoadBalancer
```bash
# Habilitar túnel (requiere privilegios de administrador)
minikube tunnel

# En otra terminal, verificar LoadBalancer
kubectl get services --watch
```

#### Configuración de LoadBalancer
```yaml
# loadbalancer-minikube.yaml
apiVersion: v1
kind: Service
metadata:
  name: minikube-loadbalancer
spec:
  type: LoadBalancer
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 8080
```

### 3. Montaje de Directorios Host

#### Configuración de Volúmenes Host
```yaml
# host-path-minikube.yaml
apiVersion: v1
kind: Pod
metadata:
  name: host-path-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: host-storage
      mountPath: /usr/share/nginx/html
  volumes:
  - name: host-storage
    hostPath:
      path: /home/user/website  # Directorio en el host de Minikube
      type: Directory
```

```bash
# Montar directorio host en Minikube
minikube mount /local/path:/minikube/path
```

### 4. Configuración de Ingress

#### NGINX Ingress específico para Minikube
```bash
# Habilitar addon de ingress
minikube addons enable ingress

# Verificar que el controller está funcionando
kubectl get pods -n ingress-nginx
```

```yaml
# ingress-minikube.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minikube-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: app.minikube.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-app-service
            port:
              number: 80
```

```bash
# Agregar entrada en /etc/hosts
echo "$(minikube ip) app.minikube.local" | sudo tee -a /etc/hosts
```

### 5. Configuración de Métricas

#### Metrics Server para Minikube
```bash
# Habilitar metrics server
minikube addons enable metrics-server

# Verificar métricas
kubectl top nodes
kubectl top pods
```

### 6. Scripts de Automatización Específicos

#### Script de Setup Completo
```bash
#!/bin/bash
# minikube-setup.sh

echo "🚀 Configurando Minikube con addons..."

# Verificar que Minikube está ejecutándose
if ! minikube status >/dev/null 2>&1; then
    echo "Iniciando Minikube..."
    minikube start --driver=docker --memory=4096 --cpus=2
fi

# Habilitar addons necesarios
echo "Habilitando addons..."
minikube addons enable dashboard
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable registry

# Configurar context
kubectl config use-context minikube

echo "✅ Minikube configurado exitosamente"
echo "📊 Dashboard: minikube dashboard"
echo "🌐 IP del cluster: $(minikube ip)"
echo "🔧 Para túnel LoadBalancer: minikube tunnel"
```

#### Script de Limpieza
```bash
#!/bin/bash
# minikube-cleanup.sh

echo "🧹 Limpiando recursos de Minikube..."

# Eliminar todos los recursos
kubectl delete all --all

# Deshabilitar addons si es necesario
# minikube addons disable dashboard
# minikube addons disable ingress
# minikube addons disable metrics-server

echo "✅ Limpieza completada"
```

### 7. Ejemplos de Desarrollo

#### Hot Reload con Minikube
```yaml
# hot-reload-minikube.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dev-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dev-app
  template:
    metadata:
      labels:
        app: dev-app
    spec:
      containers:
      - name: dev-app
        image: node:18-alpine
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo 'Dev server running...'; sleep 30; done"]
        volumeMounts:
        - name: source-code
          mountPath: /app
        ports:
        - containerPort: 3000
      volumes:
      - name: source-code
        hostPath:
          path: /path/to/local/source
```

```bash
# Sincronizar código local con pod
minikube mount $(pwd):/app
```

## 🔧 Comandos Útiles Específicos de Minikube

### Gestión del Cluster
```bash
# Ver configuración actual
minikube config view

# Cambiar recursos del cluster
minikube config set memory 8192
minikube config set cpus 4

# SSH al nodo de Minikube
minikube ssh

# Ver logs del sistema
minikube logs
```

### Docker Registry Local
```bash
# Configurar Docker para usar registry de Minikube
eval $(minikube docker-env)

# Construir imagen directamente en Minikube
docker build -t my-app:latest .

# Usar imagen sin push
kubectl set image deployment/my-app container=my-app:latest
```

### Troubleshooting Específico
```bash
# Reiniciar Minikube
minikube stop
minikube start

# Eliminar y recrear cluster
minikube delete
minikube start

# Ver estado detallado
minikube status --format=json
```

## 📝 Notas Importantes

1. **Rendimiento**: Minikube es ideal para desarrollo local, no para producción
2. **Recursos**: Ajustar memoria y CPU según las necesidades de desarrollo
3. **Addons**: Solo habilitar addons necesarios para evitar consumo excesivo de recursos
4. **Persistencia**: Los datos se pierden al eliminar el cluster a menos que uses volúmenes persistentes

## 🔗 Enlaces Útiles

- [Documentación oficial de Minikube](https://minikube.sigs.k8s.io/docs/)
- [Lista completa de addons](https://minikube.sigs.k8s.io/docs/handbook/addons/)
- [Configuración avanzada](https://minikube.sigs.k8s.io/docs/handbook/config/)
