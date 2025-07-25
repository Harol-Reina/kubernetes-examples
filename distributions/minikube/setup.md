# Guía de Instalación de Minikube

## Introducción

Minikube es una herramienta que facilita la ejecución de Kubernetes localmente. Minikube ejecuta un clúster de Kubernetes de un solo nodo dentro de una máquina virtual en tu portátil para usuarios que buscan probar Kubernetes o desarrollar con él día a día.

## Prerrequisitos

### Requisitos del Sistema
- **CPU**: 2 o más CPUs
- **Memoria**: 2GB de memoria libre
- **Disco**: 20GB de espacio libre en disco
- **Internet**: Conexión a internet
- **Hypervisor**: Docker, VirtualBox, VMware, HyperKit, o KVM

### Software Requerido
- **kubectl**: Cliente de línea de comandos de Kubernetes
- **Docker** (recomendado) o cualquier otro hypervisor compatible

## Instalación

### 1. Instalar kubectl

#### En Linux:
```bash
# Descargar la última versión estable
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Hacer el binario ejecutable
chmod +x kubectl

# Mover a PATH
sudo mv kubectl /usr/local/bin/

# Verificar instalación
kubectl version --client
```

#### En macOS:
```bash
# Usando Homebrew
brew install kubectl

# O usando curl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

#### En Windows:
```powershell
# Usando Chocolatey
choco install kubernetes-cli

# O descargar directamente
curl -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
```

### 2. Instalar Docker (Recomendado)

#### En Linux (Ubuntu/Debian):
```bash
# Actualizar paquetes
sudo apt update

# Instalar dependencias
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Añadir clave GPG oficial de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Añadir repositorio Docker
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Añadir usuario al grupo docker
sudo usermod -aG docker $USER

# Reiniciar para aplicar cambios de grupo
newgrp docker
```

#### En macOS:
```bash
# Descargar Docker Desktop desde https://www.docker.com/products/docker-desktop
# O usar Homebrew
brew install --cask docker
```

#### En Windows:
- Descargar Docker Desktop desde https://www.docker.com/products/docker-desktop

### 3. Instalar Minikube

#### En Linux:
```bash
# Descargar Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

# Instalar Minikube
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Verificar instalación
minikube version
```

#### En macOS:
```bash
# Usando Homebrew
brew install minikube

# O usando curl
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64
sudo install minikube-darwin-amd64 /usr/local/bin/minikube
```

#### En Windows:
```powershell
# Usando Chocolatey
choco install minikube

# O descargar el instalador desde GitHub
# https://github.com/kubernetes/minikube/releases/latest
```

## Configuración Inicial

### 1. Iniciar Minikube

```bash
# Iniciar Minikube con Docker como driver
minikube start --driver=docker

# Configurar Docker como driver por defecto
minikube config set driver docker

# Verificar estado
minikube status
```

### 2. Configurar kubectl para usar Minikube

```bash
# Minikube configura automáticamente kubectl, pero puedes verificar:
kubectl config current-context

# Debería mostrar: minikube
```

### 3. Verificar la Instalación

```bash
# Verificar nodos
kubectl get nodes

# Verificar servicios del sistema
kubectl get pods -n kube-system

# Obtener información del clúster
kubectl cluster-info
```

## Configuración Avanzada

### Configurar Recursos del Clúster

```bash
# Iniciar con configuraciones específicas
minikube start \
  --driver=docker \
  --cpus=4 \
  --memory=8192 \
  --disk-size=50gb \
  --kubernetes-version=v1.28.0
```

### Habilitar Addons Útiles

```bash
# Ver addons disponibles
minikube addons list

# Habilitar dashboard
minikube addons enable dashboard

# Habilitar ingress
minikube addons enable ingress

# Habilitar metrics-server
minikube addons enable metrics-server

# Habilitar registry
minikube addons enable registry
```

### Configurar Multiple Nodos (Experimental)

```bash
# Crear clúster con múltiples nodos
minikube start --nodes 3 --driver=docker
```

## Comandos Útiles

### Gestión del Clúster

```bash
# Iniciar Minikube
minikube start

# Parar Minikube
minikube stop

# Eliminar Minikube
minikube delete

# Reiniciar Minikube
minikube restart

# Ver estado
minikube status

# Ver logs
minikube logs
```

### Acceso a Servicios

```bash
# Abrir dashboard de Kubernetes
minikube dashboard

# Obtener URL de un servicio
minikube service <nombre-servicio> --url

# Abrir un servicio en el navegador
minikube service <nombre-servicio>
```

### Trabajo con Imágenes Docker

```bash
# Configurar Docker para usar el daemon de Minikube
eval $(minikube docker-env)

# Volver al daemon local de Docker
eval $(minikube docker-env -u)

# Cargar una imagen local en Minikube
minikube image load <nombre-imagen>

# Construir imagen directamente en Minikube
minikube image build -t <nombre-imagen> .
```

## Solución de Problemas Comunes

### Error: "minikube start" falla

```bash
# Verificar drivers disponibles
minikube start --help | grep -E "driver|vm-driver"

# Intentar con un driver diferente
minikube start --driver=virtualbox

# Limpiar configuración corrupta
minikube delete --all --purge
```

### Problemas de Memoria

```bash
# Verificar recursos del sistema
free -h
df -h

# Aumentar memoria asignada
minikube start --memory=4096
```

### Problemas de Red

```bash
# Verificar conectividad
minikube ssh -- ping google.com

# Verificar proxy (si aplica)
minikube start --docker-env HTTP_PROXY=http://proxy.company.com:port
```

### kubectl no funciona

```bash
# Verificar contexto
kubectl config get-contexts

# Cambiar a contexto de Minikube
kubectl config use-context minikube

# Verificar configuración
kubectl config view
```

## Desinstalación

### Eliminar Clúster y Datos

```bash
# Eliminar clúster actual
minikube delete

# Eliminar todos los clústeres y configuraciones
minikube delete --all --purge

# Eliminar binario (Linux/macOS)
sudo rm /usr/local/bin/minikube

# Eliminar directorio de configuración
rm -rf ~/.minikube
```

## Recursos Adicionales

- [Documentación oficial de Minikube](https://minikube.sigs.k8s.io/docs/)
- [Documentación de kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [Tutoriales de Kubernetes](https://kubernetes.io/docs/tutorials/)
- [Troubleshooting Guide](https://minikube.sigs.k8s.io/docs/handbook/troubleshooting/)

## Próximos Pasos

Una vez que tengas Minikube funcionando, puedes:

1. Explorar los casos de uso en `use-cases.md`
2. Probar las configuraciones de ejemplo en `kubernetes-config/`
3. Seguir los tutoriales oficiales de Kubernetes
4. Experimentar con diferentes tipos de aplicaciones
