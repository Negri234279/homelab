# Arquitectura del Homelab

## Stack Tecnológico

### Provisioning
- **Ansible**: Automatización de configuración del SO y servicios base

### Orquestación
- **K3s**: Kubernetes ligero optimizado para RPi
- **Flux CD**: GitOps para deployment automático

### Networking
- **Traefik v3**: Ingress controller y reverse proxy
- **cert-manager**: Gestión automática de certificados TLS
- **Pi-hole**: DNS local con wildcard para *.negri.es

### Infraestructura
- **Terraform**: Automatización de DNS (Cloudflare + Pi-hole)
- **Sealed Secrets**: Cifrado de secrets en Git
- **Docker Registry**: Registry privado local

## Flujo de Deployment

1. Dev push a repo de app con `homelab.yaml`
2. `register-app.sh` genera manifests K8s y Terraform DNS
3. Git commit y push al repo homelab
4. Flux detecta cambios y despliega en ~2 minutos
5. Apps disponibles en `https://<subdomain>.negri.es`

## Red

- **Red local**: 192.168.1.0/24
- **RPi5**: 192.168.1.7 (server K3s + Pi-hole)
- **RPi3**: 192.168.1.6 (worker K3s - futuro)
