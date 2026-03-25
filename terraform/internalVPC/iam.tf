#################################
# IAM – node service account
#################################
module "service_accounts" {
  source  = "terraform-google-modules/service-accounts/google"
  version = "4.7.0"

  # ── Required ────────────────────────────────────────────────────
  project_id = var.project_id

  # ── Service account identity ─────────────────────────────────────
  names        = [local.node_service_account] # "dev-01-node-identity"
  display_name = "${local.env_name} node service account"

  # ── IAM roles ───────────────────────────────────────────────────
  project_roles = [
    for role in var.node_identity_roles :
    "${var.project_id}=>${role}"
  ]
}
