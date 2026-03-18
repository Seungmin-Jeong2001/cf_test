terraform {
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 4.0" }
  }
}

provider "aws" { region = "ap-northeast-2" }
provider "cloudflare" { api_token = var.cf_api_token }

# ---------------------------------------------------------
# 1. AWS Infrastructure (EC2 & Security Group)
# ---------------------------------------------------------
resource "aws_instance" "k3s_server" {
  ami                    = "ami-0ea4d4b8dc1e46212" # Ubuntu 22.04
  instance_type          = "t3.small"
  key_name               = "chilseongpa_keypair"
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  tags                   = { Name = "k3s-server" }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
}

resource "aws_security_group" "k3s_sg" {
  name = "k3s-sg"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------
# 2. Cloudflare Zero Trust Tunnel
# ---------------------------------------------------------
resource "cloudflare_zero_trust_tunnel_cloudflared" "k8s_tunnel" {
  account_id = var.cf_account_id
  name       = "chilseong-tunnel"
  secret     = base64encode(random_string.tunnel_secret.result)
}

resource "random_string" "tunnel_secret" { length = 32 }

# 3. 터널 라우팅 룰 (Public Hostname 설정)
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

# 4. DNS 레코드 설정
resource "cloudflare_record" "app_cname" {
  zone_id = var.cf_zone_id
  name    = "app"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.k8s_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# 5. Ansible 인벤토리 자동 생성
resource "local_file" "inventory" {
  content  = <<EOT
[aws]
${aws_instance.k3s_server.public_ip} ansible_user=ubuntu ansible_private_key_file=/home/jeong/github/cf_test/chilseongpa_keypair.pem

[aws:vars]
tunnel_token=${cloudflare_zero_trust_tunnel_cloudflared.k8s_tunnel.tunnel_token}
EOT
  filename = "../ansible/inventory.ini"
}
