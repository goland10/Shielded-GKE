terraform {
  backend "gcs" {
    #project = "terraform-shared-data"
    bucket = "backends-all-projects"
  }
}
#t init -reconfigure -backend-config "prefix=dev-01/internalVPC"
#t init -reconfigure -backend-config "prefix=dev-01/app"
#t init -reconfigure -backend-config "prefix=dev-01/externalVPC"
##########################
# GKE
##########################
module "gke" {
  source     = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version    = "~> 44.0.0"
  depends_on = [module.network]

  # ── Required ────────────────────────────────────────────────────
  project_id        = var.project_id
  name              = local.env_name
  region            = var.region
  network           = "${local.env_name}-internal"
  subnetwork        = "${local.subnet_name}-gke"
  ip_range_pods     = "${local.subnet_name}-pods" 
  ip_range_services = "${local.subnet_name}-services"

  # ── Location ────────────────────────────────────────────────────
  zones    = var.zones
  regional = var.regional

  # ── Private cluster ─────────────────────────────────────────────
  enable_private_nodes    = var.enable_private_nodes
  enable_private_endpoint = var.enable_private_endpoint
  
  gcp_public_cidrs_access_enabled = false

  timeouts = var.timeouts
  
  # ── Release channel & lifecycle ─────────────────────────────────
  release_channel     = var.release_channel
  deletion_protection = var.deletion_protection

  # ── Observability ───────────────────────────────────────────────
  logging_enabled_components    = var.logging_components
  monitoring_enabled_components = var.monitoring_components

  # ── Labels ──────────────────────────────────────────────────────
  #cluster_resource_labels = var.labels

  # ── Node pool ───────────────────────────────────────────────────
  node_pools = [
    {
      name               = "${local.env_name}-pool"
      machine_type       = var.node_instance_type
      disk_size_gb       = var.node_disk_size_gb
      min_count          = var.node_min
      max_count          = var.node_max
      initial_node_count = var.node_count
      autoscaling        = true
      service_account    = module.service_accounts.service_account.email
      auto_repair        = true
      auto_upgrade       = true
      spot               = false
      #timeouts = { create = "10m"}
    }
  ]

  #node_pools_labels = {
  #  all = var.labels
  #}

  node_pools_oauth_scopes = {
    all = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]
  }
}

##########################
# Fleet 
##########################

resource "google_gke_hub_fleet" "default" {
  #  depends_on = [
  #    google_project_service.gkehub["gkehub.googleapis.com"],
  #    google_project_service.gkehub["connectgateway.googleapis.com"],
  #    module.gke
  #  ]  
}

resource "google_gke_hub_membership" "this" {
  membership_id = local.env_name

  endpoint {
    gke_cluster {
      resource_link = module.gke.cluster_id
    }
  
  }

  authority {
    issuer = "https://container.googleapis.com/v1/${module.gke.cluster_id}"
  }

  depends_on = [
    module.gke,
    google_gke_hub_fleet.default
  ]
}

#gcloud container fleet memberships get-credentials dev-01
#################################
# IAM – node service account
#################################
module "service_accounts" {
  source  = "terraform-google-modules/service-accounts/google"
  version = "4.7.0"

  # ── Required ────────────────────────────────────────────────────
  project_id = var.project_id

  # ── Service account identity ─────────────────────────────────────
  names        = [local.node_service_account] # "dev-01-node-identity"
  display_name = "${local.env_name} node service account"

  # ── IAM roles ───────────────────────────────────────────────────
  project_roles = [
    for role in var.node_identity_roles :
    "${var.project_id}=>${role}"
  ]
}
resource "google_compute_address" "nginx_ilb_ip" {
  name         = "nginx-ilb-static-ip"
  subnetwork   = "${local.subnet_name}-gke" # The subnet where your ILB lives
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
  depends_on = [ module.network ]
}

# The Helm release must have 'wait = true' to ensure the LB gets an IP 
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  wait             = true # Terraform waits for the Internal LB IP to be assigned 

  set = [
    {
      name  = "controller.service.annotations.cloud\\.google\\.com/load-balancer-type"
      value = "Internal"
    },
    {
      # This sets the actual name of the Forwarding Rule in GCP
      name  = "controller.service.annotations.networking\\.gke\\.io/internal-load-balancer-name"
      value = "${local.env_name}-internal-lb"
    },
    {
      name  = "controller.service.loadBalancerIP"
      value = google_compute_address.nginx_ilb_ip.address
    },
    {
      name  = "controller.service.annotations.networking\\.gke\\.io/internal-load-balancer-allow-global-access"
      value = "true"
    }
  ]
  depends_on = [
    google_compute_address.nginx_ilb_ip,
    google_gke_hub_membership.this
   ]
}

# Find the GCP Forwarding Rule associated with that IP

data "google_compute_forwarding_rules" "all_ilbs" {
  depends_on = [helm_release.nginx_ingress]
}

locals {
  # Logic: Find the rule in the list that matches our reserved IP
  target_rule = [
    for r in data.google_compute_forwarding_rules.all_ilbs.rules : r 
    if r.ip_address == google_compute_address.nginx_ilb_ip.address
  ][0]
}

resource "google_compute_service_attachment" "nginx_psc" {
  name                  = "nginx-psc-attachment"
  #region                = var.region
  
  # Now we have the self_link even though we didn't know the name!
  target_service        = local.target_rule.self_link
  
  connection_preference = "ACCEPT_AUTOMATIC"
  nat_subnets           = ["projects/${var.project_id}/regions/${var.region}/subnetworks/${local.subnet_name}-psc-nat"]
  enable_proxy_protocol = false
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
  project_id     = var.project_id
  network_name   = "${local.env_name}-internal"
  subnets_region = var.region

  # ── Subnets ─────────────────────────────────────────────────────
  subnets = [
    {
      subnet_name           = "${local.subnet_name}-gke"
      subnet_ip             = local.nodes_cidr
      subnet_private_access = true # required for private GKE nodes
    },
    {
      subnet_name = "${local.subnet_name}-psc-nat"
      subnet_ip   = local.psc_cidr
      purpose     = "PRIVATE_SERVICE_CONNECT"
      #role        = "ACTIVE"
    }
  ]

  # ── Secondary ranges (pods + services) ──────────────────────────
  secondary_ranges = {
    ("${local.subnet_name}-gke") = [
      {
        range_name    = "${local.subnet_name}-pods"
        ip_cidr_range = local.pods_cidr
      },
      {
        range_name    = "${local.subnet_name}-services"
        ip_cidr_range = local.services_cidr
      }
    ]
  }
}
#########################
# Firewall rules
#########################

# Enable ssh to worker nodes via iap for troublshooting
resource "google_compute_firewall" "iap" {
  name          = "allow-ssh-from-iap"
  project       = var.project_id
  network       = module.network.network_id
  direction     = "INGRESS"
  priority      = 910 
  
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"] 
  }

  # Use the same target tags as your existing GKE nodes
  target_tags = ["gke-${local.env_name}"] 
}

# Health check firewall rule
resource "google_compute_firewall" "nginx_health_check" {
  name          = "allow-nginx-psc-health-check"
  project       = var.project_id
  network       = module.network.network_id
  direction     = "INGRESS"
  priority      = 900 # Higher priority than the default 1000
  
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]

  allow {
    protocol = "tcp"
    ports    = ["80", "10254"] 
  }

  # Use the same target tags as your existing GKE nodes
  target_tags = ["${local.env_name}-internal"] 
}

###########################################################################
# Nat gateway for the gke cluster to able to pull images from the internet
###########################################################################

resource "google_compute_router" "router" {
  name    = "gke-router"
  network = "${local.env_name}-internal"       # Match your VPC name
  depends_on = [ module.network ]
}

resource "google_compute_router_nat" "nat" {
  name                               = "gke-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

output "service_attachment_uri" {
  value = google_compute_service_attachment.nginx_psc.id
}

output "gke_cluster_id" {
  sensitive = false
  value     = nonsensitive(module.gke.cluster_id)
}

output "gke_endpoint" {
  value     = nonsensitive(module.gke.endpoint)
  sensitive = false
}

output "membership_id" {
  value = google_gke_hub_membership.this.membership_id
}

output "location" {
  value = module.gke.location
}

output "zones" {
  value = module.gke.zones
}provider "google" {
  project = var.project_id
  region  = var.region
  
  default_labels = {
    env_type = var.env_type
    env_name = local.env_name
    owner    = var.owner
    project  = "commit"
  }
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  
  default_labels = {
    env_type = var.env_type
    env_name = local.env_name
    owner    = var.owner
    project  = "commit"
  }
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

variable "project_id_external" {}

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

################
# GKE Privacy
################

variable "enable_private_nodes" {
  description = "Whether the GKE cluster should be private"
  type        = bool
  default     = false
}

variable "enable_private_endpoint" {
  description = "Whether the GKE cluster should be private"
  type        = bool
  default     = false
}

variable "node_identity_roles" {
  description = "IAM roles attached to the node service account"
  type        = list(string)

  validation {
    condition     = length(var.node_identity_roles) > 0
    error_message = "node_identity_roles must contain at least one role."
  }
}

#######################################
# GKE location
#######################################
variable "regional" {
  type = bool
  description = "true for regional cluster, false for zonal cluster"
}

variable "zones" {
  type = list(string)
}

#######################################
# GKE node configuration
#######################################
variable "node_instance_type" {
  description = "Node machine / instance type"
  type        = string
}

variable "node_disk_size_gb" {
  description = "Node disk size in GB"
  type        = number
}

variable "node_min" {
  description = "Minimum number of nodes"
  type        = number
}

variable "node_max" {
  description = "Maximum number of nodes"
  type        = number
}

variable "node_count" {
  description = "Initial node count"
  type        = number
  validation {
    condition = (
      var.node_min <= var.node_count &&
      var.node_count <= var.node_max
    )

    error_message = "node_count must be between node_min and node_max."
  }
}

#######################################
# GKE cluster behavior
#######################################
variable "deletion_protection" {
  description = "Enable deletion protection for the GKE cluster"
  type        = bool
}

variable "release_channel" {
  description = "GKE release channel"
  type        = string

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be RAPID, REGULAR, or STABLE."
  }
}

variable "logging_components" {
  description = "Enabled GKE logging components"
  type        = list(string)
}

variable "monitoring_components" {
  description = "Enabled GKE monitoring components"
  type        = list(string)
}

variable "timeouts" {
  type        = map(string)
  description = "Timeout for cluster operations."
  default     = {}
  validation {
    condition     = !contains([for t in keys(var.timeouts) : contains(["create", "update", "delete"], t)], false)
    error_message = "Only create, update, delete timeouts can be specified."
  }
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
