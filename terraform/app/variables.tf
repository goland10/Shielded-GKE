#######################################
# Provider context
#######################################
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Default GCP region"
  type        = string
}

#######################################
# Environment identity
#######################################
variable "env_type" {
  description = "Environment type (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env_type)
    error_message = "env_type must be one of: dev, staging, prod."
  }
}

variable "env_number" {
  description = "Numeric environment number (e.g. 1 or 01 for dev-01, 2 or 02 for dev-02)"
  type        = number
  validation {
    condition     = var.env_number >= 1 && var.env_number <= 127
    error_message = "env_number must be between 1 and 127."
  }
}

######################################
# Labels / cost allocation
#######################################

variable "owner" {
  type        = string
  description = "Owner for this environment"
}

variable "project_id_external" {
  description = "GCP project ID for external resources"
  type        = string
}