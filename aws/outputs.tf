output "instance_ip" {
  value = aws_instance.vpn-factory-server.public_ip
}

output "ssh_keypair_name" {
  value = var.keypair_name
}

output "ramdomized_ports" {
  value = random_shuffle.vpn_ports.result
}
