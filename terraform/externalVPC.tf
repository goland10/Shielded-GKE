terraform {
  backend "gcs" {
    #project = "terraform-shared-data"
    bucket = "backends-all-projects"
  }
}
#t init -reconfigure -backend-config "prefix=dev-01/internalVPC"
#t init -reconfigure -backend-config "prefix=dev-01/app"
#t init -reconfigure -backend-config "prefix=dev-01/externalVPC"
resource "tls_private_key" "lb_private_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "lb_cert" {
  private_key_pem = tls_private_key.lb_private_key.private_key_pem

  subject {
    common_name  = var.domain_name
    organization = "Self-Signed Testing"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# I'm using the new certificate (certificate manager) approach, this is not a 'Classic' certificates
resource "google_certificate_manager_certificate" "default" {
  name        = "${local.env_name}-cert-mgr-self-signed"
  project     = var.project_id_external
  description = "Self-signed certificate in Certificate Manager"
  scope       = "DEFAULT" # Use DEFAULT for Global External Load Balancers

  self_managed {
    pem_certificate = tls_self_signed_cert.lb_cert.cert_pem
    pem_private_key = tls_private_key.lb_private_key.private_key_pem
  }
}

resource "google_certificate_manager_certificate_map" "default" {
  name    = "${local.env_name}-cert-map"
  project = var.project_id_external
}

resource "google_certificate_manager_certificate_map_entry" "default" {
  name         = "${local.env_name}-map-entry"
  project      = var.project_id_external
  map          = google_certificate_manager_certificate_map.default.name
  certificates = [google_certificate_manager_certificate.default.id]
  hostname     = var.domain_name
}
resource "google_compute_security_policy" "cloud_armor_policy" {
  name    = "${local.env_name}-security-policy"
  project = var.project_id_external

  # 1. Protocol Attack Protection (Critical for Proxies)
  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('protocolattack-v33-stable')"
      }
    }
    description = "Nginx: Block protocol attacks and smuggling"
  }

  # 2. Local File Inclusion (LFI)
  rule {
    action   = "deny(403)"
    priority = "1010"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
      }
    }
    description = "Nginx: Block path traversal"
  }

  # 3. Remote Code Execution (RCE)
  rule {
    action   = "deny(403)"
    priority = "1020"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
      }
    }
    description = "Nginx: Block shell injection"
  }

  # 4. Scanner Detection
  rule {
    action   = "deny(403)"
    priority = "1030"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('scannerdetection-v33-stable')"
      }
    }
    description = "Block vulnerability scanners"
  }

  # Default rule
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow"
  }
}#################################################################
# THE FRONTEND IP: Reserve a Global External Static IP Address
#################################################################
resource "google_compute_global_address" "lb_static_ip" {
  name    = "${local.env_name}-external-lb-ip"
  project = var.project_id_external
}

#################################################################
# FORWARDING RULE: Entry point for HTTPS traffic on port 443
#################################################################
resource "google_compute_global_forwarding_rule" "default" {
  name                  = "${local.env_name}-frontend"
  project               = var.project_id_external
  target                = google_compute_target_https_proxy.default.id
  port_range            = "443"
  ip_address            = google_compute_global_address.lb_static_ip.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

#################################################################
# HTTPS PROXY: Terminates SSL and links the Certificate Map
#################################################################
resource "google_compute_target_https_proxy" "default" {
  name    = "${local.env_name}-https-proxy"
  project = var.project_id_external
  url_map = google_compute_url_map.default.id

  # Note the specific URI format required for Certificate Manager
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.default.id}"
}

#################################################################
# URL MAP: Directs incoming requests to the Backend Service
#################################################################
resource "google_compute_url_map" "default" {
  name            = "${local.env_name}-url-map"
  project         = var.project_id_external
  default_service = google_compute_backend_service.default.id
}

#################################################################
# BACKEND SERVICE: Connects to the PSC NEG and enforces WAF
#################################################################
resource "google_compute_backend_service" "default" {
  name                  = "${local.env_name}-backend-service"
  project               = var.project_id_external
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  
  # Link the Cloud Armor policy here for WAF protection
  security_policy = google_compute_security_policy.cloud_armor_policy.id
  
  backend {
    group = google_compute_region_network_endpoint_group.psc_neg.id
  }
}
locals {
  gcp_labels_aws_tags = {
    env_type = var.env_type
    env_name = local.env_name
    owner    = var.owner
    project  = "k8s-terraform"
  }
}

locals {
  # Zero-pad env number (01, 02, etc.)
  env_number_padded = format("%02d", var.env_number)

  # Environment name
  env_name              = "${var.env_type}-${local.env_number_padded}"
  gke_hub_membership_id = local.env_name

  # Node identity
  node_service_account = "${local.env_name}-node-service-account"

  # Subnets calculation according to GKE best practices
  base_cidr     = "10.0.0.0/8"
  env_offset    = var.env_number * 2
  env_base_cidr = cidrsubnet(local.base_cidr, 8, local.env_offset)     # 10.2.0.0/16

  nodes_cidr    = cidrsubnet(local.env_base_cidr, 8, 0)                # 10.2.0.0/24
  services_cidr = cidrsubnet(local.env_base_cidr, 4, 15)               # 10.2.240.0/20
  pods_cidr     = cidrsubnet(local.base_cidr, 8, local.env_offset + 1) # 10.3.0.0/16

  psc_cidr    = "10.1.0.0/24" # CIDR for the Private Service Connect subnet required by PSC NAT
  external_cidr = "10.1.1.0/24"
  subnet_name = "${local.env_name}-subnet"
}
#########################
# Network
#########################
module "network" {
  source  = "terraform-google-modules/network/google"
  version = "16.0.1"

  # ── Required ────────────────────────────────────────────────────
  project_id     = var.project_id_external
  network_name   = "${local.env_name}-external"
  subnets_region = var.region
  routing_mode = "GLOBAL"

  # ── Subnets ─────────────────────────────────────────────────────
  subnets = [
    {
      subnet_name           = "${local.subnet_name}-external"
      subnet_ip             = local.external_cidr
      subnet_private_access = true # required for private GKE nodes
    }
  ]
}
output "external_lb_static_ip" {
  value = google_compute_global_address.lb_static_ip.address
}

output "domain_name" {
  value = var.domain_name
}

output "test_alb_command" {
  description = "Run this command to test the Load Balancer before DNS propagation."
  value       = "curl --resolve ${var.domain_name}:443:${google_compute_global_address.lb_static_ip.address} -k https://${var.domain_name}"
}
provider "google" {
  project = var.project_id_external
  region  = var.region
  
  default_labels = {
    env_type = var.env_type
    env_name = local.env_name
    owner    = var.owner
    project  = "commit"
  }
}

provider "google-beta" {
  project = var.project_id_external
  region  = var.region
  
  default_labels = {
    env_type = var.env_type
    env_name = local.env_name
    owner    = var.owner
    project  = "commit"
  }
}# Fetch the remote state of the internal project
data "terraform_remote_state" "internal_vpc" {
  backend = "gcs"
  config = {
    bucket = "backends-all-projects"
    prefix = "${local.env_name}/internalVPC"
  }
}

#t apply -var-file ../envs/dev-01.tfvars -var service_attachment_uri=$(t output -raw -state ../internalVPC/terraform.tfstate service_attachment_uri)
resource "google_compute_region_network_endpoint_group" "psc_neg" {
  name                  = "${local.env_name}-psc-neg"
  project               = var.project_id_external
  region                = var.region
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  psc_target_service    = data.terraform_remote_state.internal_vpc.outputs.service_attachment_uri  # The URI of the internal project
  
  # The network and subnetwork where the NEG resides
  network               = module.network.network_id
  subnetwork            = module.network.subnets_ids[0]
}
#######################################
# Environment identity
#######################################
variable "env_type" {
  description = "Environment type (dev, staging, prod)"
  type        = string
}

variable "env_number" {
  description = "Numeric environment number (e.g. 1 for dev-01)"
  type        = number
}

variable "owner" {
  type        = string
  description = "Owner for this environment"
}

#######################################
# Provider & Network context
#######################################
variable "project_id" {
  description = "GCP project ID for internal resources"
  type        = string
}

variable "project_id_external" {
  description = "GCP project ID for external resources"
  type        = string
}

variable "region" {
  description = "Default GCP region"
  type        = string
}

variable "domain_name" {
  description = "Domain for the SSL cert"
  type        = string
}terraform {
  # Matches your current CLI version
  required_version = ">= 1.14.3"

  required_providers {
    # Core Google Cloud Providers
    google = {
      source  = "hashicorp/google"
      version = "~> 7.24.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.24.0"
    }

    # Kubernetes & Helm Management
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.1"
    }

    # Security & Utility Providers
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.2.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.8.1"
    }
  }
}
