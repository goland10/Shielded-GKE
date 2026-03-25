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
}