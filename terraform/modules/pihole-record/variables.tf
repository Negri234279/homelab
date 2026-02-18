variable "name" {
  description = "Nombre del subdominio"
  type        = string
}

variable "local_ip" {
  description = "IP local a la que apunta el dominio"
  type        = string
}

variable "pihole_host" {
  description = "SSH user@host del RPi5"
  type        = string
}

variable "pihole_ssh_key" {
  description = "Ruta a la clave SSH privada"
  type        = string
}
