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
# Nat gateway to enable the gke cluster to pull images from the internet
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

