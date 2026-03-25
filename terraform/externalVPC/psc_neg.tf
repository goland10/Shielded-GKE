# Fetch the remote state of the internal project
data "terraform_remote_state" "internal_vpc" {
  backend = "gcs"
  config = {
    bucket = "backends-all-projects"
    prefix = "${local.env_name}/internalVPC"
  }
}

#t apply -var-file ../envs/dev-01.tfvars -var service_attachment_uri=$(t output -raw -state ../internalVPC/terraform.tfstate service_attachment_uri)
resource "google_compute_region_network_endpoint_group" "psc_neg" {
  name                  = "${local.env_name}-psc-neg"
  project               = var.project_id_external
  region                = var.region
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  psc_target_service    = data.terraform_remote_state.internal_vpc.outputs.service_attachment_uri  # The URI of the internal project
  
  # The network and subnetwork where the NEG resides
  network               = module.network.network_id
  subnetwork            = module.network.subnets_ids[0]
}
