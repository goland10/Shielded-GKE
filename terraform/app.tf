terraform {
  backend "gcs" {
    #project = "terraform-shared-data"
    bucket = "backends-all-projects"
  }
}
#t init -reconfigure -backend-config "prefix=dev-01/internalVPC"
#t init -reconfigure -backend-config "prefix=dev-01/app"
#t init -reconfigure -backend-config "prefix=dev-01/externalVPC"
# 1. THE DEPLOYMENT: The "web" app
resource "kubernetes_deployment_v1" "web" {
  metadata {
    name = "web"
    labels = {
      app = "web"
    }
  }

  spec {
    replicas = 3
    selector {
      match_labels = {
        app = "web"
      }
    }
    template {
      metadata {
        labels = {
          app = "web"
        }
      }
      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# 2. THE SERVICE: Expose the app
resource "kubernetes_service_v1" "web_service" {
  metadata {
    name = "web-service"
  }
  spec {
    selector = {
      app = "web"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

# 3. THE INGRESS: Routing logic
resource "kubernetes_ingress_v1" "web_ingress" {
  metadata {
    name = "web-ingress"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.web_service.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
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
provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  gateway_url = "https://connectgateway.googleapis.com/v1/projects/${data.google_project.this.number}/locations/global/gkeMemberships/${local.gke_hub_membership_id}"
}

provider "kubernetes" {
  host = local.gateway_url #"https://connectgateway.googleapis.com/v1/projects/${data.google_project.this.number}/locations/global/gkeMemberships/${local.gke_hub_membership_id}"

  # Assumes a Kubernetes cluster version of 1.26+
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }
}

provider "helm" {
  kubernetes = {
    host = local.gateway_url

    # Helm also needs the exec block to authenticate through the gateway
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
}
#######################################
# Provider context
#######################################
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Default GCP region"
  type        = string
}

#######################################
# Environment identity
#######################################
variable "env_type" {
  description = "Environment type (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env_type)
    error_message = "env_type must be one of: dev, staging, prod."
  }
}

variable "env_number" {
  description = "Numeric environment number (e.g. 1 or 01 for dev-01, 2 or 02 for dev-02)"
  type        = number
  validation {
    condition     = var.env_number >= 1 && var.env_number <= 127
    error_message = "env_number must be between 1 and 127."
  }
}

######################################
# Labels / cost allocation
#######################################

variable "owner" {
  type        = string
  description = "Owner for this environment"
}

variable "project_id_external" {
  description = "GCP project ID for external resources"
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
