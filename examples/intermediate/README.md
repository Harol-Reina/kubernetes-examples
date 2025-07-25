# Ejemplos Intermedios de Kubernetes

Esta carpeta contiene ejemplos de conceptos intermedios de Kubernetes que son esenciales para aplicaciones más robustas y configurables.

## 📋 Contenido

### 1. Ingress
Routing HTTP/HTTPS y terminación TLS:
- **ingress-basic.yaml**: Ingress básico para routing HTTP
- **ingress.yaml**: Configuración de Ingress avanzada

### 2. ConfigMaps
Configuración externalizada para aplicaciones:
- **configmap.yaml**: ConfigMap básico
- **configmap-env.yaml**: ConfigMap completo para variables de entorno
- **app-deployment.yaml**: Deployment que usa ConfigMap

### 3. Secrets
Gestión segura de credenciales y datos sensibles:
- **secret.yaml**: Secret básico
- **secret-generic.yaml**: Secret genérico para credenciales

### 4. Volumes y Storage
Persistencia y compartición de datos:
- **persistent-volume.yaml**: Definición de Persistent Volume
- **persistent-volume-claim.yaml**: PVC independiente
- **pod-with-storage.yaml**: Pod con volumen persistente
- **volume-pvc.yaml**: Persistent Volume Claim con deployment

### 5. Aplicaciones Multi-contenedor
Aplicaciones complejas con múltiples servicios:
- **mysql-deployment.yaml**: Base de datos MySQL
- **mysql-service.yaml**: Servicio para MySQL
- **webapp-deployment.yaml**: Aplicación web que conecta a MySQL
- **webapp-service.yaml**: Servicio para la aplicación web
- **app1-deployment.yaml**: Primera aplicación para Ingress
- **app2-deployment.yaml**: Segunda aplicación para Ingress

### 6. Múltiples Aplicaciones con Ingress
Routing avanzado para múltiples aplicaciones usando el mismo Ingress

## 🎯 Ejemplos Completos Incluidos

### Stack Completo Web + Base de Datos
Conjunto completo para aplicación con persistencia:
```bash
kubectl apply -f "5. Aplicaciones Multi-contenedor/mysql-deployment.yaml"
kubectl apply -f "5. Aplicaciones Multi-contenedor/mysql-service.yaml"
kubectl apply -f "5. Aplicaciones Multi-contenedor/webapp-deployment.yaml"
kubectl apply -f "5. Aplicaciones Multi-contenedor/webapp-service.yaml"
```

### Configuración Externa con ConfigMaps/Secrets
Demostración de configuración externalizada:
```bash
kubectl apply -f "2. ConfigMaps/configmap.yaml"
kubectl apply -f "3. Secrets/secret.yaml"
kubectl apply -f "2. ConfigMaps/app-deployment.yaml"
```

### Multi-aplicación con Ingress
Múltiples servicios detrás de un solo punto de entrada:
```bash
kubectl apply -f "5. Aplicaciones Multi-contenedor/app1-deployment.yaml"
kubectl apply -f "5. Aplicaciones Multi-contenedor/app2-deployment.yaml"
kubectl apply -f "1. Ingress/ingress.yaml"
```

## 🚀 Cómo usar estos ejemplos

```bash
# Aplicar por categorías
kubectl apply -f "2. ConfigMaps/"
kubectl apply -f "3. Secrets/"
kubectl apply -f "4. Volumes y Storage/"

# Aplicar todos los ejemplos intermedios
find . -name "*.yaml" -exec kubectl apply -f {} \;

# Ver recursos
kubectl get ingress,configmaps,secrets,pv,pvc

# Verificar configuración
kubectl describe configmap app-config
kubectl get secret app-secret -o yaml
```

## 📝 Notas

- Los Ingress requieren un Ingress Controller instalado
- Los PVC requieren un StorageClass configurado
- Los Secrets son codificados en base64 automáticamente
- Los ConfigMaps pueden ser actualizados sin recrear pods
