# Kubectl - Ejemplos y Comandos Útiles

Esta guía proporciona ejemplos prácticos y comandos útiles de `kubectl` para la gestión diaria de clusters de Kubernetes.

## Tabla de Contenidos

1. [Instalación y Configuración](#instalación-y-configuración)
2. [Comandos Básicos](#comandos-básicos)
3. [Gestión de Pods](#gestión-de-pods)
4. [Gestión de Deployments](#gestión-de-deployments)
5. [Gestión de Services](#gestión-de-services)
6. [ConfigMaps y Secrets](#configmaps-y-secrets)
7. [Gestión de Namespaces](#gestión-de-namespaces)
8. [Debugging y Troubleshooting](#debugging-y-troubleshooting)
9. [Logs y Monitoreo](#logs-y-monitoreo)
10. [Networking](#networking)
11. [Storage y Volumes](#storage-y-volumes)
12. [RBAC y Seguridad](#rbac-y-seguridad)
13. [Comandos Avanzados](#comandos-avanzados)
14. [Aliases y Shortcuts](#aliases-y-shortcuts)
15. [Scripts de Automatización](#scripts-de-automatización)

---

## Instalación y Configuración

### Instalación de kubectl

```bash
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# macOS
brew install kubectl

# Verificar instalación
kubectl version --client
```

### Configuración Básica

```bash
# Ver configuración actual
kubectl config view

# Ver contextos disponibles
kubectl config get-contexts

# Cambiar contexto
kubectl config use-context minikube

# Establecer namespace por defecto
kubectl config set-context --current --namespace=desarrollo

# Crear alias para múltiples clusters
kubectl config set-context dev --cluster=dev-cluster --user=dev-user --namespace=development
kubectl config set-context prod --cluster=prod-cluster --user=prod-user --namespace=production
```

---

## Comandos Básicos

### Información del Cluster

```bash
# Información del cluster
kubectl cluster-info

# Verificar estado de nodos
kubectl get nodes

# Información detallada de un nodo
kubectl describe node <node-name>

# Ver recursos disponibles
kubectl top nodes

# API resources disponibles
kubectl api-resources

# Versión del cluster
kubectl version
```

### Listado de Recursos

```bash
# Listar todos los pods
kubectl get pods

# Pods en todos los namespaces
kubectl get pods --all-namespaces

# Pods con más información
kubectl get pods -o wide

# Ver todos los recursos en un namespace
kubectl get all

# Recursos con labels específicos
kubectl get pods -l app=nginx

# Recursos ordenados por fecha de creación
kubectl get pods --sort-by=.metadata.creationTimestamp
```

---

## Gestión de Pods

### Crear y Gestionar Pods

```bash
# Crear pod desde imagen
kubectl run nginx --image=nginx

# Crear pod con port-forward
kubectl run nginx --image=nginx --port=80

# Crear pod con variables de entorno
kubectl run nginx --image=nginx --env="DOMAIN=cluster" --env="POD_NAMESPACE=default"

# Crear pod con límites de recursos
kubectl run nginx --image=nginx --requests='cpu=100m,memory=256Mi' --limits='cpu=200m,memory=512Mi'

# Crear pod temporal para debugging
kubectl run test-pod --image=busybox --rm -it --restart=Never -- sh

# Crear pod con comando personalizado
kubectl run nginx --image=nginx --command -- /bin/sh -c "while true; do echo hello; sleep 10; done"
```

### Información y Debugging de Pods

```bash
# Describir pod (muy útil para debugging)
kubectl describe pod <pod-name>

# Ver logs de un pod
kubectl logs <pod-name>

# Logs en tiempo real
kubectl logs -f <pod-name>

# Logs de contenedor específico en pod multi-contenedor
kubectl logs <pod-name> -c <container-name>

# Ejecutar comandos en pod
kubectl exec <pod-name> -- ls /app
kubectl exec -it <pod-name> -- /bin/bash

# Ejecutar en contenedor específico
kubectl exec -it <pod-name> -c <container-name> -- /bin/bash

# Copiar archivos hacia/desde pod
kubectl cp localfile.txt <pod-name>:/tmp/
kubectl cp <pod-name>:/tmp/remotefile.txt localfile.txt

# Port forwarding
kubectl port-forward <pod-name> 8080:80

# Ver métricas de recursos del pod
kubectl top pod <pod-name>
```

---

## Gestión de Deployments

### Crear Deployments

```bash
# Crear deployment básico
kubectl create deployment nginx --image=nginx

# Crear deployment con réplicas específicas
kubectl create deployment nginx --image=nginx --replicas=3

# Crear deployment desde archivo YAML
kubectl apply -f deployment.yaml

# Crear deployment con port y expose
kubectl create deployment nginx --image=nginx --port=80
kubectl expose deployment nginx --port=80 --target-port=80
```

### Gestionar Deployments

```bash
# Escalar deployment
kubectl scale deployment nginx --replicas=5

# Autoescalar deployment
kubectl autoscale deployment nginx --cpu-percent=50 --min=1 --max=10

# Actualizar imagen del deployment
kubectl set image deployment/nginx nginx=nginx:1.21

# Ver estado del rollout
kubectl rollout status deployment/nginx

# Ver historial de rollouts
kubectl rollout history deployment/nginx

# Rollback a versión anterior
kubectl rollout undo deployment/nginx

# Rollback a versión específica
kubectl rollout undo deployment/nginx --to-revision=2

# Pausar rollout
kubectl rollout pause deployment/nginx

# Reanudar rollout
kubectl rollout resume deployment/nginx
```

### Deployment YAML Avanzado

```yaml
# advanced-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: advanced-app
  labels:
    app: advanced-app
    version: v1.0
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  selector:
    matchLabels:
      app: advanced-app
  template:
    metadata:
      labels:
        app: advanced-app
        version: v1.0
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        env:
        - name: ENV
          value: "production"
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: database.host
        volumeMounts:
        - name: config-volume
          mountPath: /etc/config
      volumes:
      - name: config-volume
        configMap:
          name: app-config
```

---

## Gestión de Services

### Crear Services

```bash
# Exponer deployment como ClusterIP
kubectl expose deployment nginx --port=80

# Crear NodePort service
kubectl expose deployment nginx --type=NodePort --port=80

# Crear LoadBalancer service
kubectl expose deployment nginx --type=LoadBalancer --port=80

# Service con target port diferente
kubectl expose deployment nginx --port=8080 --target-port=80

# Service con nombre específico
kubectl expose deployment nginx --name=nginx-service --port=80
```

### Service YAML Examples

```yaml
# clusterip-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
---
# nodeport-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: app-nodeport
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080
  type: NodePort
---
# loadbalancer-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: app-loadbalancer
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
  type: LoadBalancer
---
# headless-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: app-headless
spec:
  clusterIP: None
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
```

---

## ConfigMaps y Secrets

### ConfigMaps

```bash
# Crear ConfigMap desde valores literales
kubectl create configmap app-config --from-literal=database.host=localhost --from-literal=database.port=5432

# Crear ConfigMap desde archivo
kubectl create configmap app-config --from-file=config.properties

# Crear ConfigMap desde directorio
kubectl create configmap app-config --from-file=config/

# Ver ConfigMap
kubectl get configmap app-config -o yaml

# Describir ConfigMap
kubectl describe configmap app-config

# Editar ConfigMap
kubectl edit configmap app-config
```

### Secrets

```bash
# Crear Secret genérico
kubectl create secret generic app-secret --from-literal=username=admin --from-literal=password=secret123

# Crear Secret desde archivo
kubectl create secret generic app-secret --from-file=credentials.txt

# Crear Secret para Docker registry
kubectl create secret docker-registry regcred \
  --docker-server=registry.io \
  --docker-username=username \
  --docker-password=password \
  --docker-email=email@example.com

# Crear Secret TLS
kubectl create secret tls tls-secret --cert=tls.crt --key=tls.key

# Ver Secret (sin mostrar valores)
kubectl get secret app-secret

# Ver Secret con valores decodificados
kubectl get secret app-secret -o jsonpath='{.data.password}' | base64 -d
```

### ConfigMap y Secret YAML

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  app.properties: |
    database.host=postgres-service
    database.port=5432
    database.name=myapp
    redis.host=redis-service
    redis.port=6379
  nginx.conf: |
    server {
        listen 80;
        location / {
            proxy_pass http://backend-service:8080;
        }
    }
---
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
data:
  database.username: YWRtaW4=  # admin
  database.password: c2VjcmV0MTIz  # secret123
  api.key: YWJjZGVmZ2hpams=  # abcdefghijk
```

---

## Gestión de Namespaces

### Operaciones con Namespaces

```bash
# Crear namespace
kubectl create namespace desarrollo

# Crear namespace desde YAML
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: desarrollo
  labels:
    environment: dev
    team: backend
EOF

# Listar namespaces
kubectl get namespaces

# Describir namespace
kubectl describe namespace desarrollo

# Eliminar namespace (cuidado: elimina todos los recursos)
kubectl delete namespace desarrollo

# Cambiar namespace por defecto
kubectl config set-context --current --namespace=desarrollo

# Verificar namespace actual
kubectl config view --minify | grep namespace
```

### Resource Quotas y Limits

```yaml
# namespace-with-quota.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: limited-namespace
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: limited-namespace
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
    pods: "10"
    services: "5"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: limited-namespace
spec:
  limits:
  - default:
      cpu: 200m
      memory: 256Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
```

---

## Debugging y Troubleshooting

### Comandos de Diagnóstico

```bash
# Estado general del cluster
kubectl get componentstatuses

# Eventos del cluster
kubectl get events --sort-by=.metadata.creationTimestamp

# Eventos en namespace específico
kubectl get events -n kube-system

# Información detallada de recurso
kubectl describe pod <pod-name>
kubectl describe service <service-name>
kubectl describe deployment <deployment-name>

# Ver logs con filtros
kubectl logs <pod-name> --since=1h
kubectl logs <pod-name> --tail=100
kubectl logs <pod-name> --since-time="2023-01-01T10:00:00Z"

# Logs de múltiples pods
kubectl logs -l app=nginx

# Debug de networking
kubectl run debug-pod --image=nicolaka/netshoot --rm -it --restart=Never
# Dentro del pod debug:
# nslookup kubernetes.default
# curl -I http://service-name.namespace.svc.cluster.local
# ping pod-ip
```

### Troubleshooting Scripts

```bash
#!/bin/bash
# debug-cluster.sh - Script para diagnosticar problemas del cluster

echo "=== CLUSTER DEBUG REPORT ==="
echo "Generated at: $(date)"
echo ""

echo "=== CLUSTER INFO ==="
kubectl cluster-info
echo ""

echo "=== NODES STATUS ==="
kubectl get nodes -o wide
echo ""

echo "=== SYSTEM PODS ==="
kubectl get pods -n kube-system
echo ""

echo "=== RECENT EVENTS ==="
kubectl get events --sort-by=.metadata.creationTimestamp | tail -20
echo ""

echo "=== FAILED PODS ==="
kubectl get pods --all-namespaces --field-selector=status.phase=Failed
echo ""

echo "=== PODS WITH RESTART COUNT > 0 ==="
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}' | awk '$3>0'
echo ""

echo "=== RESOURCE USAGE ==="
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
kubectl top pods --all-namespaces 2>/dev/null | head -20 || echo "Metrics server not available"
echo ""

echo "=== PERSISTENT VOLUMES ==="
kubectl get pv
echo ""

echo "=== SERVICES WITHOUT ENDPOINTS ==="
for service in $(kubectl get services --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace},{.metadata.name} {end}'); do
    namespace=$(echo $service | cut -d',' -f1)
    name=$(echo $service | cut -d',' -f2)
    endpoints=$(kubectl get endpoints $name -n $namespace -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
    if [ -z "$endpoints" ]; then
        echo "$namespace/$name"
    fi
done
```

---

## Logs y Monitoreo

### Comandos de Logs

```bash
# Logs básicos
kubectl logs <pod-name>

# Logs con timestamp
kubectl logs <pod-name> --timestamps

# Logs anteriores (del contenedor anterior si el pod se reinició)
kubectl logs <pod-name> --previous

# Logs de múltiples contenedores
kubectl logs <pod-name> --all-containers=true

# Logs con grep
kubectl logs <pod-name> | grep ERROR

# Logs estructurados con jq
kubectl logs <pod-name> | jq '.level, .message'

# Seguir logs en tiempo real de múltiples pods
kubectl logs -f -l app=nginx --max-log-requests=10
```

### Script de Monitoreo

```bash
#!/bin/bash
# monitor-app.sh - Script para monitorear aplicación

APP_NAME=${1:-nginx}
NAMESPACE=${2:-default}

echo "Monitoring $APP_NAME in namespace $NAMESPACE"

# Función para obtener estado
get_status() {
    echo "=== $(date) ==="
    echo "Pods:"
    kubectl get pods -l app=$APP_NAME -n $NAMESPACE
    echo ""
    
    echo "Services:"
    kubectl get services -l app=$APP_NAME -n $NAMESPACE
    echo ""
    
    echo "Deployments:"
    kubectl get deployments -l app=$APP_NAME -n $NAMESPACE
    echo ""
    
    echo "Recent Events:"
    kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$APP_NAME --sort-by=.lastTimestamp | tail -5
    echo ""
    
    echo "Resource Usage:"
    kubectl top pods -l app=$APP_NAME -n $NAMESPACE 2>/dev/null || echo "Metrics not available"
    echo "=================================="
}

# Monitoreo continuo
while true; do
    get_status
    sleep 30
done
```

---

## Networking

### Información de Red

```bash
# Ver servicios y sus endpoints
kubectl get services
kubectl get endpoints

# Información detallada de service
kubectl describe service <service-name>

# Ver Ingress
kubectl get ingress
kubectl describe ingress <ingress-name>

# Network Policies
kubectl get networkpolicies
kubectl describe networkpolicy <policy-name>

# Test de conectividad desde pod
kubectl run test --image=busybox --rm -it --restart=Never -- sh
# Dentro del pod:
# nslookup service-name
# wget -qO- http://service-name:port
# telnet service-ip port
```

### Ejemplos de Network Policies

```yaml
# deny-all-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# allow-frontend-to-backend.yaml
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
```

---

## Storage y Volumes

### Persistent Volumes

```bash
# Ver Persistent Volumes
kubectl get pv

# Ver Persistent Volume Claims
kubectl get pvc

# Describir PV/PVC
kubectl describe pv <pv-name>
kubectl describe pvc <pvc-name>

# Ver storage classes
kubectl get storageclass
```

### Ejemplos de Storage

```yaml
# persistent-volume.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: example-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /data/example
---
# persistent-volume-claim.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: example-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: manual
---
# pod-with-volume.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-storage
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - mountPath: "/usr/share/nginx/html"
      name: web-storage
  volumes:
  - name: web-storage
    persistentVolumeClaim:
      claimName: example-pvc
```

---

## RBAC y Seguridad

### Comandos de RBAC

```bash
# Ver roles y cluster roles
kubectl get roles
kubectl get clusterroles

# Ver role bindings
kubectl get rolebindings
kubectl get clusterrolebindings

# Ver service accounts
kubectl get serviceaccounts

# Verificar permisos
kubectl auth can-i create pods
kubectl auth can-i create pods --as=user1
kubectl auth can-i "*" "*" --as=system:serviceaccount:default:default
```

### Ejemplos de RBAC

```yaml
# service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-service-account
  namespace: default
---
# role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
---
# role-binding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: ServiceAccount
  name: app-service-account
  namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

---

## Comandos Avanzados

### JSON Path y Output Formatting

```bash
# JSON Path básico
kubectl get pods -o jsonpath='{.items[*].metadata.name}'

# Información específica de pods
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'

# IPs de todos los pods
kubectl get pods -o jsonpath='{.items[*].status.podIP}'

# Custom columns
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName

# Ordenar por creationTimestamp
kubectl get pods --sort-by=.metadata.creationTimestamp

# Filtrar por field selector
kubectl get pods --field-selector status.phase=Running

# Combinar label y field selectors
kubectl get pods -l app=nginx --field-selector status.phase=Running
```

### Comandos de Patch

```bash
# Patch deployment para cambiar imagen
kubectl patch deployment nginx -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","image":"nginx:1.21"}]}}}}'

# Patch con merge
kubectl patch deployment nginx --type merge -p '{"spec":{"replicas":3}}'

# Patch con strategic merge
kubectl patch deployment nginx --type strategic -p '{"spec":{"template":{"metadata":{"labels":{"version":"v2"}}}}}'

# Patch con JSON
kubectl patch pod nginx --type='json' -p='[{"op": "replace", "path": "/metadata/labels/version", "value": "v2"}]'
```

---

## Aliases y Shortcuts

### Bash Aliases Útiles

```bash
# Agregar al ~/.bashrc o ~/.zshrc

# Alias básicos
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias ka='kubectl apply'
alias kdel='kubectl delete'

# Alias para pods
alias kgp='kubectl get pods'
alias kgpo='kubectl get pods -o wide'
alias kgpa='kubectl get pods --all-namespaces'
alias kdp='kubectl describe pod'
alias kep='kubectl edit pod'

# Alias para deployments
alias kgd='kubectl get deployments'
alias kdd='kubectl describe deployment'
alias ked='kubectl edit deployment'

# Alias para services
alias kgs='kubectl get services'
alias kds='kubectl describe service'
alias kes='kubectl edit service'

# Alias para logs
alias kl='kubectl logs'
alias klf='kubectl logs -f'

# Alias para exec
alias kex='kubectl exec -it'

# Alias para namespace
alias kgns='kubectl get namespaces'
alias kcn='kubectl config set-context --current --namespace'

# Función para cambiar de contexto rápidamente
kctx() {
    if [ $# -eq 0 ]; then
        kubectl config get-contexts
    else
        kubectl config use-context $1
    fi
}
```

### Autocompletado

```bash
# Bash
echo 'source <(kubectl completion bash)' >>~/.bashrc
echo 'alias k=kubectl' >>~/.bashrc
echo 'complete -F __start_kubectl k' >>~/.bashrc

# Zsh
echo 'source <(kubectl completion zsh)' >>~/.zshrc
echo 'alias k=kubectl' >>~/.zshrc
echo 'complete -F __start_kubectl k' >>~/.zshrc
```

---

## Scripts de Automatización

### Script de Backup

```bash
#!/bin/bash
# backup-resources.sh - Backup de recursos de Kubernetes

NAMESPACE=${1:-default}
BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"

echo "Creating backup directory: $BACKUP_DIR"
mkdir -p $BACKUP_DIR

# Backup de diferentes tipos de recursos
RESOURCES=(
    "deployments"
    "services"
    "configmaps"
    "secrets"
    "persistentvolumeclaims"
    "ingresses"
)

for resource in "${RESOURCES[@]}"; do
    echo "Backing up $resource..."
    kubectl get $resource -n $NAMESPACE -o yaml > "$BACKUP_DIR/$resource.yaml"
done

# Backup de custom resources
echo "Backing up custom resources..."
kubectl get crd -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | while read crd; do
    if kubectl get $crd -n $NAMESPACE &>/dev/null; then
        kubectl get $crd -n $NAMESPACE -o yaml > "$BACKUP_DIR/custom-$crd.yaml"
    fi
done

echo "Backup completed in $BACKUP_DIR"
tar -czf "$BACKUP_DIR.tar.gz" $BACKUP_DIR/
echo "Compressed backup: $BACKUP_DIR.tar.gz"
```

### Script de Deployment Health Check

```bash
#!/bin/bash
# health-check.sh - Verificar salud de deployments

NAMESPACE=${1:-default}
TIMEOUT=${2:-300}

echo "Health check for namespace: $NAMESPACE"
echo "Timeout: $TIMEOUT seconds"

# Obtener todos los deployments
deployments=$(kubectl get deployments -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')

if [ -z "$deployments" ]; then
    echo "No deployments found in namespace $NAMESPACE"
    exit 0
fi

echo "Checking deployments: $deployments"

all_healthy=true

for deployment in $deployments; do
    echo "Checking deployment: $deployment"
    
    # Verificar que el rollout esté completo
    if kubectl rollout status deployment/$deployment -n $NAMESPACE --timeout=${TIMEOUT}s; then
        echo "✅ $deployment is healthy"
    else
        echo "❌ $deployment is not healthy"
        all_healthy=false
        
        # Mostrar información adicional
        echo "Deployment status:"
        kubectl get deployment $deployment -n $NAMESPACE
        
        echo "Pod status:"
        kubectl get pods -l app=$deployment -n $NAMESPACE
        
        echo "Recent events:"
        kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$deployment --sort-by=.lastTimestamp | tail -5
    fi
    echo ""
done

if $all_healthy; then
    echo "✅ All deployments are healthy"
    exit 0
else
    echo "❌ Some deployments are not healthy"
    exit 1
fi
```

### Script de Limpieza

```bash
#!/bin/bash
# cleanup-resources.sh - Limpiar recursos no utilizados

NAMESPACE=${1:-default}
DRY_RUN=${2:-false}

echo "Cleanup script for namespace: $NAMESPACE"
echo "Dry run: $DRY_RUN"

# Función para ejecutar o mostrar comando
run_command() {
    if [ "$DRY_RUN" = "true" ]; then
        echo "DRY RUN: $1"
    else
        echo "Executing: $1"
        eval $1
    fi
}

# Limpiar pods completados
echo "=== Cleaning completed pods ==="
completed_pods=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Succeeded -o jsonpath='{.items[*].metadata.name}')
for pod in $completed_pods; do
    run_command "kubectl delete pod $pod -n $NAMESPACE"
done

# Limpiar pods fallidos
echo "=== Cleaning failed pods ==="
failed_pods=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Failed -o jsonpath='{.items[*].metadata.name}')
for pod in $failed_pods; do
    run_command "kubectl delete pod $pod -n $NAMESPACE"
done

# Limpiar ConfigMaps no utilizados
echo "=== Finding unused ConfigMaps ==="
all_configmaps=$(kubectl get configmaps -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
used_configmaps=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.volumes[*].configMap.name}' | tr ' ' '\n' | sort -u)

for cm in $all_configmaps; do
    if ! echo "$used_configmaps" | grep -q "^$cm$"; then
        echo "Unused ConfigMap: $cm"
        # run_command "kubectl delete configmap $cm -n $NAMESPACE"
    fi
done

# Limpiar Secrets no utilizados (excluyendo service account tokens)
echo "=== Finding unused Secrets ==="
all_secrets=$(kubectl get secrets -n $NAMESPACE -o jsonpath='{.items[?(@.type!="kubernetes.io/service-account-token")].metadata.name}')
used_secrets=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.volumes[*].secret.secretName}' | tr ' ' '\n' | sort -u)

for secret in $all_secrets; do
    if ! echo "$used_secrets" | grep -q "^$secret$"; then
        echo "Unused Secret: $secret"
        # run_command "kubectl delete secret $secret -n $NAMESPACE"
    fi
done

echo "Cleanup completed"
```

Esta guía cubre los comandos más útiles de kubectl para la gestión diaria de Kubernetes. Cada sección incluye ejemplos prácticos que pueden adaptarse a diferentes necesidades y entornos.
