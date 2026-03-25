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

resource "google_gke_hub_fleet" "default" {}

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
