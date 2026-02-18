# Copilot Instructions — Homelab RPi5

## Contexto del proyecto
Homelab sobre Kubernetes (K3s) en Raspberry Pi 5. Stack: Ansible + K3s + Flux CD + Traefik + cert-manager + Terraform + Pi-hole.

## Convenciones importantes

### Nuevas apps
Siempre crear un `homelab.yaml` siguiendo el esquema en `/homelab.schema.json`.
Usar `./scripts/register-app.sh` para registrar la app, nunca crear manifests manualmente.

### Visibilidad
- `visibility: private` → Middleware Traefik `private-allowlist` → DNS en Pi-hole vía Terraform
- `visibility: public` → Middleware Traefik `secure-headers + rate-limit-public` → DNS en Cloudflare vía Terraform

### Namespaces K8s
- `traefik` → Traefik y middlewares
- `cert-manager` → cert-manager
- `kube-system` → Sealed Secrets
- `apps` → Todas las apps de usuario

### Secrets
NUNCA commitear secrets en texto plano. Usar siempre Sealed Secrets:
```bash
kubectl create secret generic <nombre> --dry-run=client -o yaml | \
  kubeseal --format yaml > k8s/apps/<app>/sealed-secret.yaml
```

### Traefik middlewares (namespaced)
Al referenciar middlewares en anotaciones, usar el formato:
`<namespace>-<nombre>@kubernetescrd`
Ejemplo: `traefik-private-allowlist@kubernetescrd`

### Imágenes Docker
- Build local (ARM64): `docker buildx build --platform linux/arm64`
- Siempre publicar en GHCR: `ghcr.io/<usuario>/<app>:<sha>`

## Archivos que NO editar manualmente
- `terraform/apps/*.tf` → generados por `register-app.sh`
- `k8s/apps/*/` → generados por `register-app.sh`
- `k8s/flux-system/` → gestionado por Flux
