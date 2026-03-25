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
