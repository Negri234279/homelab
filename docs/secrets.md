# Gestión de Secrets

## Principios
- **NUNCA** commitear secrets en texto plano
- Usar **Sealed Secrets** para todo lo que va a Git
- Las variables de entorno sensibles van como `secretRef` en `homelab.yaml`

## Flujo de trabajo

### 1. Obtener la clave pública del cluster
```bash
kubeseal --fetch-cert \
  --controller-name=sealed-secrets \
  --controller-namespace=kube-system \
  > pub-sealed-secrets.pem
```

### 2. Crear y sellar un secret
```bash
kubectl create secret generic nombre-secret \
  --namespace=apps \
  --from-literal=clave=valor \
  --dry-run=client -o yaml | \
  kubeseal --format yaml \
    --cert pub-sealed-secrets.pem \
  > k8s/apps/mi-app/sealed-secret.yaml
```

### 3. Referenciar en el Deployment
```yaml
env:
  - name: MI_VARIABLE
    valueFrom:
      secretKeyRef:
        name: nombre-secret
        key: clave
```

## Secrets de infraestructura

### Cloudflare API Token (para cert-manager y Traefik)
```bash
kubectl create secret generic cloudflare-api-token \
  --namespace=traefik \
  --from-literal=token=TU_CF_TOKEN \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > k8s/infrastructure/traefik/sealed-cloudflare-token.yaml
```

El token de Cloudflare necesita permisos:
- Zone → Zone → Read
- Zone → DNS → Edit
