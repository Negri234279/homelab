# Cómo añadir una nueva app al homelab

## 1. Crear el repositorio de la app en GitHub

El repo puede tener cualquier nombre. Debe incluir:
- El código fuente
- Un `Dockerfile` (si `image.source: dockerfile`)
- Un `homelab.yaml` en la raíz

## 2. Crear el homelab.yaml

Copia y adapta uno de estos ejemplos según el tipo de app:

### App privada (solo LAN)
```yaml
app:
  name: mi-app
  subdomain: mi-app
  visibility: private
  port: 8080
  image:
    source: dockerfile
  resources:
    memory: 256Mi
```

### App pública (internet)
```yaml
app:
  name: mi-blog
  subdomain: blog
  visibility: public
  port: 80
  image:
    source: registry
    registry: nginx:alpine
```

## 3. Registrar la app

```bash
git clone https://github.com/<usuario>/mi-app /tmp/mi-app
./scripts/register-app.sh /tmp/mi-app
```

El script:
1. Genera los manifests K8s en `k8s/apps/mi-app/`
2. Genera el módulo Terraform DNS en `terraform/apps/mi-app.tf`
3. Aplica el DNS (Pi-hole o Cloudflare según visibilidad)
4. Hace commit y push
5. Flux detecta el cambio y despliega en ~2 minutos

## 4. Verificar el despliegue

```bash
# Ver pods
kubectl get pods -n apps

# Ver el Ingress
kubectl get ingress -n apps

# Ver el certificado TLS
kubectl get certificate -n apps

# Ver logs de Traefik
kubectl logs -n traefik -l app.kubernetes.io/name=traefik

# Ver logs de la app
kubectl logs -n apps -l app=mi-app
```

## 5. Secrets

Si tu app necesita secrets:

```bash
# Crear el secret (sin commitear)
kubectl create secret generic mi-app-secret \
  --from-literal=password='mi_contraseña' \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > k8s/apps/mi-app/sealed-secret.yaml

# Añadir al kustomization.yaml de la app
echo "  - sealed-secret.yaml" >> k8s/apps/mi-app/kustomization.yaml

# Commitear el SealedSecret (es seguro, está cifrado)
git add k8s/apps/mi-app/sealed-secret.yaml
git commit -m "feat: add sealed secret for mi-app"
git push
```
