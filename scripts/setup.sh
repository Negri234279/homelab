#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# setup.sh — Configura los placeholders no sensibles del repo
# Uso: ./scripts/setup.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$REPO_ROOT/.setup.env"

# Colores
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo "=================================================="
echo " Homelab — Configuración inicial de placeholders"
echo "=================================================="
echo ""

# Cargar valores previos si existen
if [[ -f "$CONFIG_FILE" ]]; then
  echo -e "${YELLOW}Cargando configuración existente de .setup.env${NC}"
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

# Pedir valores (usar valor actual como default si ya existe)
read -rp "GitHub username [${GITHUB_USER:-}]: " input
GITHUB_USER="${input:-${GITHUB_USER:-}}"

read -rp "Email para cert-manager y Cloudflare ACME [${ACME_EMAIL:-}]: " input
ACME_EMAIL="${input:-${ACME_EMAIL:-}}"

echo ""
echo -e "${YELLOW}Los valores sensibles (CF_API_TOKEN, ZONE_ID, IP_PUBLICA) van en:${NC}"
echo "  → terraform/terraform.tfvars  (gitignored)"
echo "  → Ansible Vault para pihole_web_password"
echo ""

# Validar que no estén vacíos
if [[ -z "$GITHUB_USER" || -z "$ACME_EMAIL" ]]; then
  echo -e "${RED}Error: GITHUB_USER y ACME_EMAIL son obligatorios${NC}"
  exit 1
fi

# Guardar para futuros usos (no sensible)
cat > "$CONFIG_FILE" <<EOF
GITHUB_USER="$GITHUB_USER"
ACME_EMAIL="$ACME_EMAIL"
EOF

echo ""
echo "Sustituyendo placeholders..."

# Archivos a procesar
FILES=(
  "$REPO_ROOT/ansible/roles/k3s-server/defaults/main.yml"
  "$REPO_ROOT/k8s/infrastructure/traefik/values.yaml"
  "$REPO_ROOT/k8s/infrastructure/cert-manager/clusterissuer-cloudflare.yaml"
  "$REPO_ROOT/README.md"
  "$REPO_ROOT/scripts/generate-k8s-manifest.sh"
)

for FILE in "${FILES[@]}"; do
  if [[ -f "$FILE" ]]; then
    sed -i "s|<<TU_USUARIO>>|$GITHUB_USER|g" "$FILE"
    sed -i "s|<<TU_EMAIL>>|$ACME_EMAIL|g" "$FILE"
    echo -e "  ${GREEN}✓${NC} $(basename "$FILE")"
  fi
done

echo ""
echo -e "${GREEN}Hecho.${NC} Próximos pasos:"
echo ""
echo "  1. Configura terraform/terraform.tfvars:"
echo "     cp terraform/terraform.tfvars.example terraform/terraform.tfvars"
echo "     # editar con CF_API_TOKEN, ZONE_ID, IP_PUBLICA"
echo ""
echo "  2. Cifra la contraseña de Pi-hole con Ansible Vault:"
echo "     ansible-vault encrypt_string 'TU_PASSWORD' --name 'pihole_web_password'"
echo "     # pegar el resultado en ansible/roles/pihole/defaults/main.yml"
echo ""
echo "  3. Commitea los cambios no sensibles:"
echo "     git add -u && git commit -m 'chore: configure placeholders'"
