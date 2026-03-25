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
