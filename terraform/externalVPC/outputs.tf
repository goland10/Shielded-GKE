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
