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
