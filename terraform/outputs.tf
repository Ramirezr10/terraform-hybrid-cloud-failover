output "aws_lighthouse_public_ip" {
  value = aws_instance.lighthouse_primary.public_ip
}

output "gcp_standby_public_ip" {
  # This uses a splat [*] because the instance might not exist (count = 0)
  value = google_compute_instance.vm_instance[*].network_interface[0].access_config[0].nat_ip
}
