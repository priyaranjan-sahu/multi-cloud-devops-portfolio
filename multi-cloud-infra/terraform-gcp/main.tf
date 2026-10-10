terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.6"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 8.6"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "devops-portfolio-local"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "devops-portfolio"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "ssh_source_ranges" {
  description = "CIDR ranges allowed to SSH (default: Google IAP tunnel range, avoids exposing 22 to the internet)"
  type        = list(string)
  default     = ["35.235.240.0/20"]
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  labels = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
    repository  = "multi-cloud-devops-portfolio"
  }
}

resource "google_compute_network" "main" {
  name                    = "${local.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  description             = "VPC for DevOps Portfolio"
}

resource "google_compute_subnetwork" "public" {
  name          = "${local.name_prefix}-public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.main.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "private" {
  name          = "${local.name_prefix}-private-subnet"
  ip_cidr_range = "10.0.10.0/24"
  region        = var.region
  network       = google_compute_network.main.id
  private_ip_google_access = true
}

resource "google_compute_firewall" "allow_http" {
  name    = "${local.name_prefix}-allow-http"
  network = google_compute_network.main.name
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
  description   = "Allow HTTP traffic"
}

resource "google_compute_firewall" "allow_https" {
  name    = "${local.name_prefix}-allow-https"
  network = google_compute_network.main.name
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["https-server"]
  description   = "Allow HTTPS traffic"
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${local.name_prefix}-allow-ssh"
  network = google_compute_network.main.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = var.ssh_source_ranges
  target_tags   = ["ssh-access"]
  description   = "Allow SSH traffic from trusted ranges only"
}

resource "google_compute_firewall" "allow_health_check" {
  name    = "${local.name_prefix}-allow-health-check"
  network = google_compute_network.main.name
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["http-server"]
  description   = "Allow GCP health checks"
}

resource "google_compute_instance_template" "app" {
  name_prefix  = "${local.name_prefix}-app-template-"
  machine_type = "e2-micro"
  region       = var.region

  disk {
    boot         = true
    auto_delete  = true
    source_image = "debian-cloud/debian-12"
    disk_size_gb = 10
    disk_type    = "pd-balanced"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private.id
    access_config {
      nat_ip = google_compute_address.nat_ip.address
    }
  }

  tags = ["http-server", "https-server", "ssh-access"]

  metadata = {
    startup-script = <<-EOF
      #!/bin/bash
      apt-get update
      apt-get install -y nginx
      cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head><title>DevOps Portfolio - GCP</title></head>
<body style="font-family:sans-serif;text-align:center;padding:50px;background:linear-gradient(135deg,#1e3c72,#2a5298);color:white;">
<h1>🚀 GCP Deployment</h1>
<p>Deployed with Terraform on Google Cloud</p>
<div style="margin-top:20px;">
<span style="background:rgba(255,255,255,0.2);padding:5px 15px;border-radius:20px;margin:5px;display:inline-block;">GCP</span>
<span style="background:rgba(255,255,255,0.2);padding:5px 15px;border-radius:20px;margin:5px;display:inline-block;">Terraform</span>
<span style="background:rgba(255,255,255,0.2);padding:5px 15px;border-radius:20px;margin:5px;display:inline-block;">DevOps</span>
</div>
</body>
</html>
HTMLEOF
      systemctl enable nginx
      systemctl start nginx
    EOF
  }

  service_account {
    email  = google_service_account.app.email
    scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

  labels = local.labels
}

resource "google_compute_address" "nat_ip" {
  name = "${local.name_prefix}-nat-ip"
  region = var.region
}

resource "google_service_account" "app" {
  account_id   = "${local.name_prefix}-app-sa"
  display_name = "DevOps Portfolio App Service Account"
}

resource "google_project_iam_member" "app_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.app.email}"
}

resource "google_storage_bucket" "app" {
  name     = "${local.name_prefix}-${random_id.suffix.hex}-app-bucket"
  location = var.region
  labels   = local.labels
  versioning {
    enabled = true
  }
  encryption {
    default_kms_key_name = google_kms_crypto_key.app.id
  }
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age            = 90
      matches_prefix = ["temp/"]
    }
  }
}

resource "google_kms_key_ring" "app" {
  name     = "${local.name_prefix}-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "app" {
  name            = "${local.name_prefix}-crypto-key"
  key_ring        = google_kms_key_ring.app.id
  rotation_period = "7776000s"
}

resource "google_compute_instance_group_manager" "app" {
  name               = "${local.name_prefix}-igm"
  base_instance_name = "${local.name_prefix}-app"
  version {
    instance_template = google_compute_instance_template.app.id
  }
  target_size        = 2
  zone               = var.zone
}

resource "google_compute_health_check" "app" {
  name               = "${local.name_prefix}-health-check"
  check_interval_sec = 30
  timeout_sec        = 10
  healthy_threshold  = 2
  unhealthy_threshold = 3
  http_health_check {
    port        = 80
    request_path = "/"
  }
}

resource "google_compute_backend_service" "app" {
  name                  = "${local.name_prefix}-backend"
  health_checks         = [google_compute_health_check.app.id]
  backend {
    group           = google_compute_instance_group_manager.app.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
  protocol = "HTTP"
  timeout_sec = 30
  port_name = "http"
}

resource "google_compute_url_map" "app" {
  name            = "${local.name_prefix}-url-map"
  default_service = google_compute_backend_service.app.id
}

resource "google_compute_target_http_proxy" "app" {
  name    = "${local.name_prefix}-http-proxy"
  url_map = google_compute_url_map.app.id
}

resource "google_compute_global_forwarding_rule" "app" {
  name       = "${local.name_prefix}-forwarding-rule"
  target     = google_compute_target_http_proxy.app.id
  port_range = "80"
  ip_protocol = "TCP"
}

output "vpc_name" {
  value = google_compute_network.main.name
}

output "load_balancer_ip" {
  value = google_compute_global_forwarding_rule.app.ip_address
}

output "bucket_name" {
  value = google_storage_bucket.app.name
}

output "instance_group_name" {
  value = google_compute_instance_group_manager.app.name
}