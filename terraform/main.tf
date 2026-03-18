terraform {
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 4.0" }
  }
}

provider "aws" { region = "ap-northeast-2" }
provider "cloudflare" { api_token = var.cf_api_token }

# 최신 Amazon Linux 2023 AMI 데이터 소스
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

# 1. AWS EC2 인스턴스
resource "aws_instance" "k3s_server" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.small"
  key_name               = "chilseongpa_keypair"
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  tags                   = { Name = "k3s-server" }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    iops        = 3000
    throughput  = 125
  }
}

# 2. 보안 그룹
resource "aws_security_group" "k3s_sg" {
  name = "k3s-sg"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Cloudflare 터널 생성
resource "cloudflare_zero_trust_tunnel_cloudflared" "k8s_tunnel" {
  account_id = var.cf_account_id
  name       = "chilseong-tunnel"
  secret     = base64encode(random_string.tunnel_secret.result) # base64encoding 권장
}

resource "random_string" "tunnel_secret" { length = 32 }

# 4. DNS 레코드 (Cloudflare Tunnel과 도메인 연결)
resource "cloudflare_record" "app_cname" {
  zone_id = var.cf_zone_id
  name    = "app"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.k8s_tunnel.id}.cfargotunnel.com" # value 대신 content 사용
  type    = "CNAME"
  proxied = true
}

# 5. Ansible 인벤토리 자동 생성
resource "local_file" "inventory" {
  content  = "[aws]\n${aws_instance.k3s_server.public_ip} ansible_user=ec2-user ansible_private_key_file=${path.cwd}/../chilseongpa_keypair.pem tunnel_token=${cloudflare_zero_trust_tunnel_cloudflared.k8s_tunnel.tunnel_token}"
  filename = "../ansible/inventory.ini"
}
