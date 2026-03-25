#######################################
# Environment identity
#######################################
variable "env_type" {
  description = "Environment type (dev, staging, prod)"
  type        = string
}

variable "env_number" {
  description = "Numeric environment number (e.g. 1 for dev-01)"
  type        = number
}

variable "owner" {
  type        = string
  description = "Owner for this environment"
}

#######################################
# Provider & Network context
#######################################
variable "project_id" {
  description = "GCP project ID for internal resources"
  type        = string
}

variable "project_id_external" {
  description = "GCP project ID for external resources"
  type        = string
}

variable "region" {
  description = "Default GCP region"
  type        = string
}

variable "domain_name" {
  description = "Domain for the SSL cert"
  type        = string
}