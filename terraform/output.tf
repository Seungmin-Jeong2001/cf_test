output "tunnel_token" {
  value     = cloudflare_zero_trust_tunnel_cloudflared.k8s_tunnel.tunnel_token
  sensitive = true
}

output "aws_instance_ip" {
  value = aws_instance.k3s_server.public_ip
}