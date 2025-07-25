# Kubernetes Examples

Este repositorio contiene ejemplos prácticos, configuraciones y guías completas de Kubernetes organizados por distribuciones, escenarios de uso y herramientas.

## 🚀 Descripción

Kubernetes Examples es una colección completa de recursos para aprender, implementar y gestionar aplicaciones en Kubernetes. Incluye configuraciones para diferentes distribuciones de Kubernetes, escenarios de desarrollo, producción y CI/CD, además de guías prácticas para herramientas esenciales.

## 📁 Estructura del Repositorio

```
kubernetes-examples/
├── README.md                          # Este archivo
├── examples/                          # Ejemplos genéricos de Kubernetes (funcionan en cualquier distribución)
│   ├── README.md                     # Guía de uso de ejemplos
│   ├── basic/                        # Ejemplos básicos (Pod, Service, Deployment)
│   ├── intermediate/                 # Ejemplos intermedios (Ingress, ConfigMap, Secrets)
│   ├── advanced/                     # Ejemplos avanzados (StatefulSet, DaemonSet, Jobs)
│   └── production/                   # Configuraciones para producción
├── distributions/                     # Configuraciones específicas por distribución
│   ├── minikube/                     # Desarrollo local con Minikube
│   │   ├── setup.md                  # Guía de instalación
│   │   ├── scripts/                  # Scripts de automatización
│   │   └── specific-configs/         # Configuraciones específicas de Minikube
│   ├── kind/                         # Testing con Kind (Kubernetes in Docker)
│   │   ├── setup.md                  # Guía de instalación
│   │   ├── scripts/                  # Scripts de automatización
│   │   └── specific-configs/         # Configuraciones específicas de Kind
│   ├── k3s/                          # Edge computing con k3s
│   │   ├── setup.md                  # Guía de instalación
│   │   ├── scripts/                  # Scripts de automatización
│   │   └── specific-configs/         # Configuraciones específicas de k3s
│   └── kubeadm/                      # Clusters completos con kubeadm
│       ├── setup.md                  # Guía de instalación
│       ├── scripts/                  # Scripts de automatización
│       └── specific-configs/         # Configuraciones específicas de kubeadm
└── docs/                             # Documentación adicional
    ├── best-practices.md
    ├── troubleshooting.md
    └── networking-guide.md
```

## 🎯 Casos de Uso Cubiertos

### Ejemplos Genéricos (carpeta `/examples/`)
- **Basic**: Pods, Services, Deployments, ReplicaSets
- **Intermediate**: Ingress, ConfigMaps, Secrets, Volumes
- **Advanced**: StatefulSets, DaemonSets, Jobs, CronJobs
- **Production**: Alta disponibilidad, monitoreo, logging, seguridad

### Distribuciones de Kubernetes
- **Minikube**: Desarrollo local con addons específicos (dashboard, ingress, metrics-server)
- **Kind**: Testing rápido con configuraciones multi-nodo y port mapping
- **k3s**: Despliegues edge con Traefik, ServiceLB y Local Storage
- **kubeadm**: Instalaciones personalizadas de producción con HA y certificados

### Configuraciones Específicas por Distribución
Cada distribución incluye configuraciones que aprovechan sus características únicas:
- **Minikube**: Addons, túneles, profiles
- **Kind**: Clusters multi-nodo, registry local, CI/CD optimizado
- **k3s**: Traefik IngressRoute, ServiceLB, optimizaciones edge
- **kubeadm**: Configuración completa de cluster, etcd externo, upgrades

## 🛠️ Tecnologías Incluidas

- **Kubernetes** (v1.28+)
- **Docker** y **Containerd**
- **Helm** v3
- **Ingress Controllers** (NGINX, Traefik)
- **Service Mesh** (Istio básico)
- **Monitoring** (Prometheus, Grafana)
- **Logging** (ELK Stack)
- **Databases** (PostgreSQL, MongoDB, Redis)
- **CI/CD** (GitHub Actions, GitLab CI)

## 🚀 Cómo Empezar

### 1. Usar los Ejemplos Genéricos
Los ejemplos en la carpeta `/examples/` funcionan en cualquier distribución de Kubernetes:

```bash
# Aplicar ejemplos básicos
kubectl apply -f examples/basic/

# Aplicar ejemplos intermedios
kubectl apply -f examples/intermediate/

# Aplicar configuración de producción
kubectl apply -f examples/production/
```

### 2. Configurar una Distribución Específica
Cada distribución tiene su propia guía de instalación:

```bash
# Para Minikube (desarrollo local)
cd distributions/minikube
./scripts/setup-minikube.sh

# Para Kind (testing rápido)
cd distributions/kind
./scripts/setup-kind.sh

# Para k3s (edge computing)
cd distributions/k3s
./scripts/setup-k3s.sh

# Para kubeadm (producción)
cd distributions/kubeadm
sudo ./scripts/kubeadm-cluster-setup.sh
```

### 3. Explorar Configuraciones Específicas
Cada distribución incluye configuraciones que aprovechan sus características únicas:

```bash
# Configuraciones específicas de Minikube
kubectl apply -f distributions/minikube/specific-configs/

# Configuraciones específicas de Kind
kind create cluster --config distributions/kind/specific-configs/kind-multi-worker-config.yaml

# Configuraciones específicas de k3s
kubectl apply -f distributions/k3s/specific-configs/traefik-ingressroute.yaml

# Configuraciones específicas de kubeadm
kubeadm init --config distributions/kubeadm/specific-configs/kubeadm-config.yaml
```

## 📚 Guías Incluidas

### Para Desarrolladores
- Setup de entornos de desarrollo con hot reload
- Debugging de aplicaciones en Kubernetes
- Testing de microservicios

### Para DevOps
- Configuración de clusters de producción
- Implementación de CI/CD pipelines
- Monitoreo y logging

### Para SRE
- Alta disponibilidad y disaster recovery
- Escalabilidad automática
- Security best practices

## 🔧 Requisitos Previos

### Software Necesario
- **Docker** (v20.10+)
- **kubectl** (v1.28+)
- **Helm** (v3.10+)

### Para Distribuciones Específicas
- **Minikube**: VirtualBox o Docker Desktop
- **Kind**: Docker instalado
- **k3s**: Máquina Linux (VM o física)
- **kubeadm**: Múltiples nodos Linux

### Recursos Mínimos
- **RAM**: 4GB (8GB recomendado)
- **CPU**: 2 cores (4 cores recomendado)
- **Disk**: 20GB disponibles

## 📖 Documentación Detallada

Cada directorio contiene documentación específica:

- **setup.md**: Instrucciones de instalación y configuración
- **use-cases.md**: Casos de uso prácticos con ejemplos
- **kubernetes-config/**: Manifiestos YAML listos para usar

### Documentación por Distribución
- [Minikube Setup Guide](distributions/minikube/setup.md)
- [Kind Configuration](distributions/kind/setup.md)
- [k3s Installation](distributions/k3s/setup.md)
- [kubeadm Setup](distributions/kubeadm/setup.md)

### Documentación por Escenario
- [Development Environment](scenarios/dev-environment/setup.md)
- [Production Deployment](scenarios/production/setup.md)
- [CI/CD Pipeline](scenarios/ci-cd/setup.md)

### Herramientas
- [kubectl Examples](tools/kubectl/kubectl-examples.md)
- [Helm Charts Guide](tools/helm/helm-examples.md)

## 🤝 Contribuciones

¡Las contribuciones son bienvenidas! Por favor:

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -am 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Crea un Pull Request

### Áreas de Contribución
- Nuevas distribuciones de Kubernetes
- Casos de uso adicionales
- Mejoras en la documentación
- Scripts de automatización
- Ejemplos de aplicaciones

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo [LICENSE](LICENSE) para más detalles.

## 🆘 Soporte

- **Issues**: Reporta bugs o solicita features en [GitHub Issues](https://github.com/tu-usuario/kubernetes-examples/issues)
- **Discussions**: Únete a la conversación en [GitHub Discussions](https://github.com/tu-usuario/kubernetes-examples/discussions)
- **Email**: contacto@ejemplo.com

## 🏷️ Tags y Versiones

- **v1.0.0**: Release inicial con distribuciones básicas
- **v1.1.0**: Agregados escenarios de producción
- **v1.2.0**: Integración de herramientas CI/CD

## 🔄 Roadmap

### v1.3.0 (Próximo)
- [ ] Soporte para EKS, GKE, AKS
- [ ] Ejemplos con Argo CD
- [ ] Monitoring avanzado con Prometheus

### v1.4.0 (Futuro)
- [ ] Service Mesh con Istio
- [ ] GitOps workflows
- [ ] Multi-cluster management

## ⭐ Agradecimientos

Gracias a la comunidad de Kubernetes y a todos los contribuyentes que hacen posible este proyecto.

---

**¿Te resulta útil este repositorio? ¡Dale una ⭐ en GitHub!**
