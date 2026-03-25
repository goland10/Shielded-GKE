# -------------------------------------------------------------------
# Environment identity
# -------------------------------------------------------------------
env_type = "dev"
env_number = 1
#env_name = "dev-01"

# -------------------------------------------------------------------
# Labels / cost allocation
# -------------------------------------------------------------------
owner = "golan"

# -------------------------------------------------------------------
# IAM (node service account)
# -------------------------------------------------------------------
#node_identity = "dev-01-node-identity"

node_identity_roles = [
  "roles/logging.logWriter",
  "roles/monitoring.metricWriter",
  "roles/monitoring.viewer",
]

# -------------------------------------------------------------------
# Location
# -------------------------------------------------------------------
#In case of zonal cluster (regional = false), 'zones' must include at least one zone
regional = false
zones = ["europe-west2-b"]      # London

enable_private_nodes = true
enable_private_endpoint = true

# -------------------------------------------------------------------
# GKE node configuration
# -------------------------------------------------------------------
node_instance_type = "e2-medium"  # e2-medium | e2-standard-4 | n2-standard-4
node_disk_size_gb  = 20           # 20 | 30 | 50

node_min   = 1
node_max   = 3
node_count = 1

# -------------------------------------------------------------------
# GKE cluster behavior
# -------------------------------------------------------------------
deletion_protection = false
release_channel     = "RAPID"   # RAPID | REGULAR | STABLE and more

logging_components    = ["SYSTEM_COMPONENTS"]   # "SYSTEM_COMPONENTS"
monitoring_components = ["SYSTEM_COMPONENTS"]   # "SYSTEM_COMPONENTS"

timeouts = {
  create = "10m"
}
