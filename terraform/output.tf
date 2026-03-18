output "aws_tunnel_token" {
  value     = cloudflare_zero_trust_tunnel_cloudflared.aws_tunnel.tunnel_token
  sensitive = true
}

output "gcp_tunnel_token" {
  value     = cloudflare_zero_trust_tunnel_cloudflared.gcp_tunnel.tunnel_token
  sensitive = true
}

output "aws_instance_ip" {
  value = aws_instance.k3s_server.public_ip
}

output "gcp_instance_ip" {
  value = google_compute_instance.gcp_server.network_interface[0].access_config[0].nat_ip
}

output "load_balancer_hostname" {
  value = "${cloudflare_load_balancer.lb.name}.${var.cf_zone_id}" # Note: This might need adjustment to get full FQDN depending on zone data
  description = "The hostname of the Load Balancer"
}
