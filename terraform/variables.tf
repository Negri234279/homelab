variable "cloudflare_api_token" {
  description = "Cloudflare API Token con permisos Zone:Edit y DNS:Edit"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Zone ID de negri.es en Cloudflare"
  type        = string
}

variable "rpi5_public_ip" {
  description = "IP pública del router (para apps públicas)"
  type        = string
}

variable "rpi5_local_ip" {
  description = "IP local del RPi5 (192.168.1.7)"
  type        = string
  default     = "192.168.1.7"
}

variable "pihole_host" {
  description = "Host SSH del RPi5 para gestionar Pi-hole"
  type        = string
  default     = "pi@192.168.1.7"
}

variable "pihole_ssh_key" {
  description = "Ruta a la clave SSH privada para conectar al RPi5"
  type        = string
  default     = "~/.ssh/homelab_rsa"
}
