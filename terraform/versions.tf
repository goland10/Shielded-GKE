terraform {
  # Matches your current CLI version
  required_version = ">= 1.14.3"

  required_providers {
    # Core Google Cloud Providers
    google = {
      source  = "hashicorp/google"
      version = "~> 7.24.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.24.0"
    }

    # Kubernetes & Helm Management
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.1"
    }

    # Security & Utility Providers
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.2.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.8.1"
    }
  }
}
