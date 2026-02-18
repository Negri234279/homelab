# Apps desplegadas — este archivo es gestionado por register-app.sh
# No editar manualmente, usar: ./scripts/register-app.sh

# Ejemplo de app privada (DNS en Pi-hole):
# module "grafana_dns" {
#   source    = "./modules/pihole-record"
#   name      = "grafana"
#   local_ip  = var.rpi5_local_ip
#   pihole_host   = var.pihole_host
#   pihole_ssh_key = var.pihole_ssh_key
# }

# Ejemplo de app pública (DNS en Cloudflare):
# module "blog_dns" {
#   source       = "./modules/cloudflare-record"
#   name         = "blog"
#   zone_id      = var.cloudflare_zone_id
#   public_ip    = var.rpi5_public_ip
#   proxied      = true
# }
