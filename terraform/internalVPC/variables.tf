#######################################
# Provider context
#######################################
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "project_id_external" {}

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

################
# GKE Privacy
################

variable "enable_private_nodes" {
  description = "Whether the GKE cluster should be private"
  type        = bool
  default     = false
}

variable "enable_private_endpoint" {
  description = "Whether the GKE cluster should be private"
  type        = bool
  default     = false
}

variable "node_identity_roles" {
  description = "IAM roles attached to the node service account"
  type        = list(string)

  validation {
    condition     = length(var.node_identity_roles) > 0
    error_message = "node_identity_roles must contain at least one role."
  }
}

#######################################
# GKE location
#######################################
variable "regional" {
  type = bool
  description = "true for regional cluster, false for zonal cluster"
}

variable "zones" {
  type = list(string)
}

#######################################
# GKE node configuration
#######################################
variable "node_instance_type" {
  description = "Node machine / instance type"
  type        = string
}

variable "node_disk_size_gb" {
  description = "Node disk size in GB"
  type        = number
}

variable "node_min" {
  description = "Minimum number of nodes"
  type        = number
}

variable "node_max" {
  description = "Maximum number of nodes"
  type        = number
}

variable "node_count" {
  description = "Initial node count"
  type        = number
  validation {
    condition = (
      var.node_min <= var.node_count &&
      var.node_count <= var.node_max
    )

    error_message = "node_count must be between node_min and node_max."
  }
}

#######################################
# GKE cluster behavior
#######################################
variable "deletion_protection" {
  description = "Enable deletion protection for the GKE cluster"
  type        = bool
}

variable "release_channel" {
  description = "GKE release channel"
  type        = string

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be RAPID, REGULAR, or STABLE."
  }
}

variable "logging_components" {
  description = "Enabled GKE logging components"
  type        = list(string)
}

variable "monitoring_components" {
  description = "Enabled GKE monitoring components"
  type        = list(string)
}

variable "timeouts" {
  type        = map(string)
  description = "Timeout for cluster operations."
  default     = {}
  validation {
    condition     = !contains([for t in keys(var.timeouts) : contains(["create", "update", "delete"], t)], false)
    error_message = "Only create, update, delete timeouts can be specified."
  }
}