#!/usr/bin/env bash
# Genera módulo Terraform para DNS local en Pi-hole
NAME="$1"
SUBDOMAIN="$2"

cat <<EOF
# Auto-generado por register-app.sh — no editar
module "${NAME}_dns" {
  source         = "./modules/pihole-record"
  name           = "$SUBDOMAIN"
  local_ip       = var.rpi5_local_ip
  pihole_host    = var.pihole_host
  pihole_ssh_key = var.pihole_ssh_key
}
EOF
