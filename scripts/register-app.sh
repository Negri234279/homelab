#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# register-app.sh — Registra una app en el homelab
# Uso: ./scripts/register-app.sh /ruta/al/repo-de-la-app
# =============================================================================

APP_REPO="${1:?Error: proporciona la ruta al repo de la app}"
CONFIG="$APP_REPO/homelab.yaml"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Verificar dependencias
for cmd in yq kubectl terraform git; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Dependencia no encontrada: $cmd"
    exit 1
  fi
done

# Verificar que existe homelab.yaml
if [[ ! -f "$CONFIG" ]]; then
  echo "❌ No se encontró homelab.yaml en $APP_REPO"
  exit 1
fi

# Parsear configuración
NAME=$(yq '.app.name' "$CONFIG")
SUBDOMAIN=$(yq '.app.subdomain' "$CONFIG")
VISIBILITY=$(yq '.app.visibility' "$CONFIG")
PORT=$(yq '.app.port' "$CONFIG")
NAMESPACE=$(yq '.app.namespace // "apps"' "$CONFIG")
IMAGE_SOURCE=$(yq '.app.image.source' "$CONFIG")
MEMORY=$(yq '.app.resources.memory // "256Mi"' "$CONFIG")

echo "🚀 Registrando app: $NAME"
echo "   Subdominio: $SUBDOMAIN.negri.es"
echo "   Visibilidad: $VISIBILITY"
echo "   Puerto: $PORT"
echo "   Namespace: $NAMESPACE"

# 1. Generar manifests K8s
K8S_DIR="$REPO_ROOT/k8s/apps/$NAME"
echo ""
echo "📦 Generando manifests K8s en $K8S_DIR..."
"$SCRIPT_DIR/generate-k8s-manifest.sh" "$CONFIG" "$K8S_DIR"

# 2. Generar Terraform DNS
echo ""
echo "🌐 Configurando DNS ($VISIBILITY)..."
TF_FILE="$REPO_ROOT/terraform/apps/${NAME}.tf"
mkdir -p "$REPO_ROOT/terraform/apps"

if [[ "$VISIBILITY" == "public" ]]; then
  "$SCRIPT_DIR/generate-tf-cloudflare.sh" "$NAME" "$SUBDOMAIN" > "$TF_FILE"
  echo "   → Registro A en Cloudflare para $SUBDOMAIN.negri.es"
else
  "$SCRIPT_DIR/generate-tf-pihole.sh" "$NAME" "$SUBDOMAIN" > "$TF_FILE"
  echo "   → Registro dnsmasq en Pi-hole para $SUBDOMAIN.negri.es"
fi

# 3. Aplicar Terraform
echo ""
echo "⚙️  Aplicando Terraform DNS..."
cd "$REPO_ROOT/terraform"
terraform init -upgrade -input=false
terraform apply -target="module.${NAME}_dns" -auto-approve -input=false

# 4. Git commit y push
echo ""
echo "📤 Haciendo commit y push..."
cd "$REPO_ROOT"
git add "k8s/apps/$NAME/" "terraform/apps/${NAME}.tf"
git commit -m "feat: add app $NAME ($SUBDOMAIN.negri.es, $VISIBILITY)"
git push

echo ""
echo "✅ App '$NAME' registrada exitosamente."
echo "   Flux desplegará la app en ~2 minutos."
echo "   URL: https://$SUBDOMAIN.negri.es"
