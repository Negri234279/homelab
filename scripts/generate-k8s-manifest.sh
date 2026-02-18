#!/usr/bin/env bash
set -euo pipefail

CONFIG="$1"
OUTPUT_DIR="$2"

NAME=$(yq '.app.name' "$CONFIG")
SUBDOMAIN=$(yq '.app.subdomain' "$CONFIG")
VISIBILITY=$(yq '.app.visibility' "$CONFIG")
PORT=$(yq '.app.port' "$CONFIG")
NAMESPACE=$(yq '.app.namespace // "apps"' "$CONFIG")
IMAGE_SOURCE=$(yq '.app.image.source' "$CONFIG")
MEMORY=$(yq '.app.resources.memory // "256Mi"' "$CONFIG")
CPU=$(yq '.app.resources.cpu // "250m"' "$CONFIG")

# Determinar imagen
if [[ "$IMAGE_SOURCE" == "registry" ]]; then
  IMAGE=$(yq '.app.image.registry' "$CONFIG")
elif [[ "$IMAGE_SOURCE" == "dockerfile" ]]; then
  IMAGE="registry.local/$NAME:latest"    # Registry local en K3s
elif [[ "$IMAGE_SOURCE" == "ghcr" ]]; then
  IMAGE="ghcr.io/<<TU_USUARIO>>/$NAME:latest"
fi

# Determinar middleware de Traefik según visibilidad
if [[ "$VISIBILITY" == "private" ]]; then
  MIDDLEWARE="traefik-private-allowlist@kubernetescrd"
else
  MIDDLEWARE="traefik-secure-headers@kubernetescrd,traefik-rate-limit-public@kubernetescrd"
fi

mkdir -p "$OUTPUT_DIR"

# kustomization.yaml
cat > "$OUTPUT_DIR/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: $NAMESPACE
resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml
EOF

# Añadir PVC si hay volúmenes
if yq -e '.app.volumes | length > 0' "$CONFIG" &>/dev/null; then
  echo "  - pvc.yaml" >> "$OUTPUT_DIR/kustomization.yaml"
fi

# deployment.yaml
cat > "$OUTPUT_DIR/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $NAME
  namespace: $NAMESPACE
  labels:
    app: $NAME
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $NAME
  template:
    metadata:
      labels:
        app: $NAME
    spec:
      containers:
        - name: $NAME
          image: $IMAGE
          ports:
            - containerPort: $PORT
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "$MEMORY"
              cpu: "$CPU"
EOF

# service.yaml
cat > "$OUTPUT_DIR/service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: $NAME
  namespace: $NAMESPACE
spec:
  selector:
    app: $NAME
  ports:
    - port: $PORT
      targetPort: $PORT
      protocol: TCP
EOF

# ingress.yaml
cat > "$OUTPUT_DIR/ingress.yaml" <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $NAME
  namespace: $NAMESPACE
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: "websecure"
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.tls.certresolver: "cloudflare"
    traefik.ingress.kubernetes.io/router.middlewares: "$MIDDLEWARE"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: traefik
  rules:
    - host: $SUBDOMAIN.negri.es
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: $NAME
                port:
                  number: $PORT
  tls:
    - hosts:
        - $SUBDOMAIN.negri.es
      secretName: $NAME-tls
EOF

echo "✅ Manifests K8s generados en $OUTPUT_DIR"
