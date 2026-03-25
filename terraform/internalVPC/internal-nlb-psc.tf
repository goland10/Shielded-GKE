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
  name                  = "nginx-psc-attachment-${local.env_name}"
  #region                = var.region
  
  # Now we have the self_link even though we didn't know the name!
  target_service        = local.target_rule.self_link
  
  connection_preference = "ACCEPT_AUTOMATIC"
  nat_subnets           = ["projects/${var.project_id}/regions/${var.region}/subnetworks/${local.subnet_name}-psc-nat"]
  enable_proxy_protocol = false
}
