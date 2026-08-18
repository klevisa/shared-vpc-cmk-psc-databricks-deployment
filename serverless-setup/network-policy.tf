# -----------------------------------------------------------------------------
# OPTIONAL serverless egress lockdown (off by default).
#
# When restrict_serverless_egress = true, create a RESTRICTED_ACCESS network policy and
# point the workspace at it. Defaults to DRY_RUN so violations are logged, not blocked —
# roll out safely, then flip egress_enforcement_mode to ENFORCED once the allowlist is
# complete. NOTE: before ENFORCED, also allowlist your GCS buckets as storage
# destinations (not modeled here — see the README) or serverless loses catalog access.
# -----------------------------------------------------------------------------

resource "databricks_account_network_policy" "serverless_egress" {
  count             = var.restrict_serverless_egress ? 1 : 0
  provider          = databricks.accounts
  network_policy_id = var.network_policy_id

  egress = {
    network_access = {
      restriction_mode = "RESTRICTED_ACCESS"
      allowed_internet_destinations = [
        for d in var.allowed_internet_destinations : {
          destination               = d
          internet_destination_type = "DNS_NAME"
        }
      ]
      policy_enforcement = {
        enforcement_mode = var.egress_enforcement_mode
      }
    }
  }
}

# Point the workspace at the policy. This is an UPDATE of the workspace's network option
# (you can't create/delete it — absent an assignment the workspace uses "default-policy").
resource "databricks_workspace_network_option" "this" {
  count             = var.restrict_serverless_egress ? 1 : 0
  provider          = databricks.accounts
  workspace_id      = var.workspace_id
  network_policy_id = databricks_account_network_policy.serverless_egress[0].network_policy_id
}
