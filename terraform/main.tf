# ... (기존 설정 동일) ...

# 3. Cloudflare 터널 생성
resource "cloudflare_zero_trust_tunnel_cloudflared" "k8s_tunnel" {
  account_id = var.cf_account_id
  name       = "chilseong-tunnel"
  secret     = base64encode(random_string.tunnel_secret.result)
}

resource "random_string" "tunnel_secret" { length = 32 }

# [추가] 터널 설정 (Ingress Rule): 
# 대시보드의 'Public Hostname' 설정을 코드로 구현한 것입니다.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "aws_tunnel_config" {
  account_id = var.cf_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.k8s_tunnel.id

  config {
    ingress_rule {
      hostname = "app.bucheongoyangijanggun.com"
      service  = "http://nginx-service:80"
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# 4. DNS 레코드 
resource "cloudflare_record" "app_cname" {
  zone_id = var.cf_zone_id
  name    = "app"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.k8s_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# 5. Ansible 인벤토리 자동 생성 (토큰 포함)
resource "local_file" "inventory" {
  content  = <<EOT
[aws]
${aws_instance.k3s_server.public_ip} ansible_user=ec2-user ansible_private_key_file=${path.cwd}/../chilseongpa_keypair.pem

[aws:vars]
tunnel_token=${cloudflare_zero_trust_tunnel_cloudflared.k8s_tunnel.tunnel_token}
EOT
  filename = "../ansible/inventory.ini"
}
