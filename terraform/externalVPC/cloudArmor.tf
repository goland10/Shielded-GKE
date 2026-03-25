resource "google_compute_security_policy" "cloud_armor_policy" {
  name    = "${local.env_name}-security-policy"
  project = var.project_id_external

  # 1. Protocol Attack Protection (Critical for Proxies)
  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('protocolattack-v33-stable')"
      }
    }
    description = "Nginx: Block protocol attacks and smuggling"
  }

  # 2. Local File Inclusion (LFI)
  rule {
    action   = "deny(403)"
    priority = "1010"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
      }
    }
    description = "Nginx: Block path traversal"
  }

  # 3. Remote Code Execution (RCE)
  rule {
    action   = "deny(403)"
    priority = "1020"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
      }
    }
    description = "Nginx: Block shell injection"
  }

  # 4. Scanner Detection
  rule {
    action   = "deny(403)"
    priority = "1030"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('scannerdetection-v33-stable')"
      }
    }
    description = "Block vulnerability scanners"
  }

  # Default rule
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow"
  }
}