#!/usr/bin/env bash
# Genera módulo Terraform para DNS público en Cloudflare
NAME="$1"
SUBDOMAIN="$2"

cat <<EOF
# Auto-generado por register-app.sh — no editar
module "${NAME}_dns" {
  source     = "./modules/cloudflare-record"
  name       = "$SUBDOMAIN"
  zone_id    = var.cloudflare_zone_id
  public_ip  = var.rpi5_public_ip
  proxied    = true
}
EOF
