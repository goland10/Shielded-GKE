#################################################################
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
