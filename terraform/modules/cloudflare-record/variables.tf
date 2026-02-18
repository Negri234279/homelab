variable "zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "name" {
  description = "Nombre del subdominio (sin .negri.es)"
  type        = string
}

variable "public_ip" {
  description = "IP pública para el registro A"
  type        = string
}

variable "proxied" {
  description = "Si Cloudflare actúa como proxy (CDN + protección)"
  type        = bool
  default     = true
}

variable "create_www" {
  description = "Crear también registro www.subdominio"
  type        = bool
  default     = false
}
