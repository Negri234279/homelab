# Outputs del módulo cloudflare-record
output "fqdn" {
  description = "FQDN del registro creado"
  value       = "${var.name}.negri.es"
}
