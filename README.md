# 🏠 Homelab RPi5

Infraestructura como código para Raspberry Pi 5 con Kubernetes (K3s), Flux CD, Traefik y automatización DNS completa.

## Stack

| Capa | Herramienta |
|---|---|
| OS Provisioning | Ansible |
| Orquestación | K3s (Kubernetes) |
| GitOps | Flux CD |
| Ingress + TLS | Traefik v3 + cert-manager |
| DNS local | Pi-hole |
| DNS remoto | Terraform + Cloudflare |
| Secrets en Git | Sealed Secrets |

## Inicio rápido

### 1. Clonar y configurar

```bash
git clone https://github.com/<<TU_USUARIO>>/homelab
cd homelab
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Editar terraform.tfvars con tus valores
```

### 2. Provisionar el RPi5

```bash
cd ansible
ansible-galaxy install -r requirements.yml
ansible-playbook playbooks/bootstrap-rpi5.yml
```

### 3. Inicializar Flux

```bash
export GITHUB_TOKEN=<<TU_GITHUB_TOKEN>>
flux bootstrap github \
  --owner=<<TU_USUARIO>> \
  --repository=homelab \
  --branch=main \
  --path=k8s/flux-system \
  --personal
```

### 4. Añadir una app

Ver [docs/adding-new-app.md](docs/adding-new-app.md)

## Estructura

```
homelab/
├── ansible/        # Provisioning del SO y K3s
├── k8s/            # Manifests Kubernetes (gestionado por Flux)
├── terraform/      # Automatización DNS
├── scripts/        # Herramientas de gestión
└── docs/           # Documentación
```

## Apps

<!-- Lista auto-generada por register-app.sh -->

| App | Subdominio | Visibilidad |
|-----|-----------|-------------|
| _vacío_ | | |
