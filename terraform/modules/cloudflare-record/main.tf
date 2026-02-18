resource "cloudflare_record" "app" {
  zone_id = var.zone_id
  name    = var.name          # subdomain
  content = var.public_ip
  type    = "A"
  ttl     = 1                 # Auto cuando proxied=true
  proxied = var.proxied
}

# Registrar subdominio www si es necesario
resource "cloudflare_record" "app_www" {
  count   = var.create_www ? 1 : 0
  zone_id = var.zone_id
  name    = "www.${var.name}"
  content = var.public_ip
  type    = "A"
  ttl     = 1
  proxied = var.proxied
}
