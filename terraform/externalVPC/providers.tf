provider "google" {
  project = var.project_id_external
  region  = var.region
  
  default_labels = {
    env_type = var.env_type
    env_name = local.env_name
    owner    = var.owner
    project  = "commit"
  }
}

provider "google-beta" {
  project = var.project_id_external
  region  = var.region
  
  default_labels = {
    env_type = var.env_type
    env_name = local.env_name
    owner    = var.owner
    project  = "commit"
  }
}