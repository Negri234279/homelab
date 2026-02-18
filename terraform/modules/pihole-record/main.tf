resource "null_resource" "pihole_dns_record" {
  triggers = {
    name     = var.name
    local_ip = var.local_ip
  }

  provisioner "local-exec" {
    command = <<-EOT
      ssh -i ${var.pihole_ssh_key} -o StrictHostKeyChecking=no ${var.pihole_host} \
        "echo 'address=/${var.name}.negri.es/${var.local_ip}' | \
         sudo tee /etc/dnsmasq.d/02-${var.name}.conf && \
         sudo pihole restartdns"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      ssh -i ${self.triggers.pihole_ssh_key} -o StrictHostKeyChecking=no ${var.pihole_host} \
        "sudo rm -f /etc/dnsmasq.d/02-${self.triggers.name}.conf && \
         sudo pihole restartdns"
    EOT
  }
}
