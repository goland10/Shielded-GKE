provider "google" {
  project = var.project_id
  region  = var.region
  
  default_labels = {
    env_type = var.env_type
    env_name = local.env_name
    owner    = var.owner
    project  = "commit"
  }
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  
  default_labels = {
    env_type = var.env_type
    env_name = local.env_name
    owner    = var.owner
    project  = "commit"
  }
}

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  gateway_url = "https://connectgateway.googleapis.com/v1/projects/${data.google_project.this.number}/locations/global/gkeMemberships/${local.gke_hub_membership_id}"
}

provider "kubernetes" {
  host = local.gateway_url #"https://connectgateway.googleapis.com/v1/projects/${data.google_project.this.number}/locations/global/gkeMemberships/${local.gke_hub_membership_id}"

  # Assumes a Kubernetes cluster version of 1.26+
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }
}

provider "helm" {
  kubernetes = {
    host = local.gateway_url

    # Helm also needs the exec block to authenticate through the gateway
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
}
