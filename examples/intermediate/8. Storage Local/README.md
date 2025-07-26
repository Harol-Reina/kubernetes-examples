# Storage Local para Bare Metal

Configuración de almacenamiento local persistente para clusters Kubernetes en bare metal sin proveedores de almacenamiento en la nube.

## 🎯 Opciones de StorageClass para Bare Metal

### 1. **Local Path Provisioner** (Recomendado)
- ✅ **Fácil instalación**: Un solo YAML
- ✅ **Dinámico**: Crea directorios automáticamente
- ✅ **Mantenimiento mínimo**: Auto-gestión de volúmenes
- ✅ **Compatible**: Funciona en cualquier distribución Linux

### 2. **Hostpath Provisioner**
- ✅ **Simple**: Usa directorios del host directamente
- ❌ **Manual**: Requiere pre-crear directorios
- ❌ **No dinámico**: Gestión manual de volúmenes

### 3. **Local Static Provisioner**
- ✅ **Rendimiento**: Mejor para cargas intensivas
- ❌ **Complejo**: Configuración más elaborada
- ❌ **Mantenimiento**: Requiere gestión manual de discos

## 🚀 Instalación Local Path Provisioner

### Instalación Automática
```bash
# Instalar desde repositorio oficial
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml

# Configurar como StorageClass por defecto
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Instalación Manual (Incluida en este ejemplo)
```bash
# Usar configuración incluida
kubectl apply -f local-path-provisioner.yaml
kubectl apply -f storageclass-local.yaml
```

## 📁 Estructura de Directorios

El provisioner creará automáticamente:
```
/opt/local-path-provisioner/
├── pvc-123abc/          # Cada PVC obtiene su directorio
├── pvc-456def/
└── pvc-789ghi/
```

## 🔧 Configuración Personalizada

### Cambiar Directorio Base
```yaml
# Editar ConfigMap para cambiar ubicación
data:
  config.json: |-
    {
      "nodePathMap":[
        {
          "node":"DEFAULT_PATH_FOR_NON_LISTED_NODES",
          "paths":["/data/local-storage"]  # Cambiar aquí
        }
      ]
    }
```

### Múltiples Nodos
```yaml
# Configuración para diferentes nodos
data:
  config.json: |-
    {
      "nodePathMap":[
        {
          "node":"node1",
          "paths":["/mnt/disk1","/mnt/disk2"]
        },
        {
          "node":"node2", 
          "paths":["/data/storage"]
        },
        {
          "node":"DEFAULT_PATH_FOR_NON_LISTED_NODES",
          "paths":["/opt/local-path-provisioner"]
        }
      ]
    }
```

## 📋 Ejemplos de Uso

### PVC Básico
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
```

### Pod con Almacenamiento Local
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: test-pvc
```

## ⚙️ Configuraciones Avanzadas

### StorageClass con Políticas
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path-retain
provisioner: rancher.io/local-path
reclaimPolicy: Retain          # No eliminar datos
allowVolumeExpansion: false    # No redimensionar
volumeBindingMode: WaitForFirstConsumer
```

### Para Bases de Datos
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path-database
provisioner: rancher.io/local-path
reclaimPolicy: Retain
volumeBindingMode: Immediate
parameters:
  # Configuraciones específicas si las hay
```

## 🔍 Verificación y Troubleshooting

### Verificar Instalación
```bash
# Comprobar pods del provisioner
kubectl get pods -n local-path-storage

# Verificar StorageClass
kubectl get storageclass

# Ver configuración
kubectl get configmap local-path-config -n local-path-storage -o yaml
```

### Verificar Funcionamiento
```bash
# Crear PVC de prueba
kubectl apply -f test-pvc.yaml

# Verificar PVC
kubectl get pvc

# Ver detalles del volumen
kubectl describe pvc test-pvc

# Verificar en el nodo
ls -la /opt/local-path-provisioner/
```

### Problemas Comunes

#### PVC en estado Pending
```bash
# Verificar eventos
kubectl describe pvc <pvc-name>

# Comprobar logs del provisioner
kubectl logs -n local-path-storage deployment/local-path-provisioner
```

#### Permisos de Directorio
```bash
# En cada nodo, asegurar permisos
sudo mkdir -p /opt/local-path-provisioner
sudo chmod 755 /opt/local-path-provisioner
```

#### Sin StorageClass por Defecto
```bash
# Configurar como default
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

## 📊 Monitoreo de Storage

### Verificar Uso de Almacenamiento
```bash
# En cada nodo
df -h /opt/local-path-provisioner

# Ver PVCs y su uso
kubectl get pvc --all-namespaces
kubectl top pv
```

### Limpieza de Volúmenes Huérfanos
```bash
# Listar volúmenes sin PVC
sudo find /opt/local-path-provisioner -maxdepth 1 -type d -name "pvc-*"

# Script de limpieza (usar con cuidado)
./cleanup-orphaned-volumes.sh
```

## ⚠️ Consideraciones Importantes

### Para Bare Metal
- **Backup**: Los datos están en el nodo local, planificar backups
- **Disponibilidad**: Si el nodo falla, los datos no están disponibles
- **Rendimiento**: Depende del almacenamiento local del nodo
- **Escalabilidad**: Limitado por el espacio local disponible

### Alternativas para HA
- **Longhorn**: Para replicación entre nodos
- **OpenEBS**: Solución más completa
- **Rook-Ceph**: Para clusters grandes

### Recomendaciones
- **Usar SSD**: Para mejor rendimiento
- **Monitorear espacio**: Alertas cuando se agote
- **Backup regular**: De datos críticos
- **Documentar ubicaciones**: De volúmenes importantes

---

**💡 Para la mayoría de casos en bare metal, Local Path Provisioner es la opción más práctica y confiable.**
