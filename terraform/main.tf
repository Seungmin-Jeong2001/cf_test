terraform {
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
    google     = { source = "hashicorp/google", version = "~> 5.0" }
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 4.0" }
    random     = { source = "hashicorp/random", version = "~> 3.0" }
    local      = { source = "hashicorp/local", version = "~> 2.0" }
  }
}

provider "aws" { region = "ap-northeast-2" }
provider "cloudflare" { api_token = var.cf_api_token }
provider "google" {
  project     = var.gcp_project_id
  region      = var.gcp_region
  credentials = var.gcp_credentials
}

data "cloudflare_zone" "domain" {
  zone_id = var.cf_zone_id
}

# -------------------------------------------------------------------
# AWS Resources (Sub)
# -------------------------------------------------------------------

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

resource "aws_instance" "k3s_server" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.small"
  key_name               = "chilseongpa_keypair"
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  tags                   = { Name = "k3s-server-aws" }

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
    cidr_blocks = var.ssh_cidr_blocks
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "random_string" "tunnel_secret_aws" { length = 32 }

resource "cloudflare_zero_trust_tunnel_cloudflared" "aws_tunnel" {
  account_id = var.cf_account_id
  name       = "chilseong-tunnel-aws"
  secret     = base64encode(random_string.tunnel_secret_aws.result)
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "aws_config" {
  account_id = var.cf_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.aws_tunnel.id

  config {
    ingress_rule {
      hostname = "app.bucheongoyangijanggun.com"
      service  = "http://localhost:80"
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# -------------------------------------------------------------------
# GCP Resources (Main)
# -------------------------------------------------------------------

resource "google_compute_instance" "gcp_server" {
  name         = "k3s-server-gcp"
  machine_type = "e2-medium"
  zone         = var.gcp_zone

  metadata = {
    ssh-keys = "ubuntu:${file("../gcp_key.pub")}"
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  tags = ["ssh-server"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = var.ssh_cidr_blocks
  target_tags   = ["ssh-server"]
}

resource "random_string" "tunnel_secret_gcp" { length = 32 }

resource "cloudflare_zero_trust_tunnel_cloudflared" "gcp_tunnel" {
  account_id = var.cf_account_id
  name       = "chilseong-tunnel-gcp"
  secret     = base64encode(random_string.tunnel_secret_gcp.result)
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "gcp_config" {
  account_id = var.cf_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.gcp_tunnel.id

  config {
    ingress_rule {
      hostname = "app.bucheongoyangijanggun.com"
      service  = "http://localhost:80"
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# -------------------------------------------------------------------
# Cloudflare Load Balancer (Tunnel 기반 Failover)
# -------------------------------------------------------------------

resource "cloudflare_load_balancer_monitor" "monitor" {
  account_id     = var.cf_account_id
  type           = "http"
  path           = "/"
  port           = 80
  interval       = 60
  retries        = 2
  expected_codes = "200"
  # hostname 제거, LB Pool origin 주소 기준으로 헬스 체크
}

resource "cloudflare_load_balancer_pool" "gcp_pool" {
  account_id = var.cf_account_id
  name       = "gcp-main-pool"
  monitor    = cloudflare_load_balancer_monitor.monitor.id
  origins {
    name    = "gcp-origin"
    address = "${cloudflare_zero_trust_tunnel_cloudflared.gcp_tunnel.id}.cfargotunnel.com"
  }
}

resource "cloudflare_load_balancer_pool" "aws_pool" {
  account_id = var.cf_account_id
  name       = "aws-sub-pool"
  monitor    = cloudflare_load_balancer_monitor.monitor.id
  origins {
    name    = "aws-origin"
    address = "${cloudflare_zero_trust_tunnel_cloudflared.aws_tunnel.id}.cfargotunnel.com"
  }
}

resource "cloudflare_load_balancer" "lb" {
  zone_id = var.cf_zone_id
  name    = "app.bucheongoyangijanggun.com"

  # 메인: GCP Tunnel
  default_pool_ids = [cloudflare_load_balancer_pool.gcp_pool.id]

  # 장애 시: AWS Tunnel
  fallback_pool_id = cloudflare_load_balancer_pool.aws_pool.id

  proxied = true
}

# -------------------------------------------------------------------
# Ansible Inventory
# -------------------------------------------------------------------

resource "local_file" "inventory" {
  content = <<EOT
[aws]
${aws_instance.k3s_server.public_ip} ansible_user=ec2-user ansible_private_key_file=${path.cwd}/../chilseongpa_keypair.pem tunnel_token=${cloudflare_zero_trust_tunnel_cloudflared.aws_tunnel.tunnel_token}

[gcp]
${google_compute_instance.gcp_server.network_interface[0].access_config[0].nat_ip} ansible_user=ubuntu ansible_private_key_file=${path.cwd}/../gcp_key tunnel_token=${cloudflare_zero_trust_tunnel_cloudflared.gcp_tunnel.tunnel_token}
EOT
  filename = "../ansible/inventory.ini"
}