# -----------------------------------------------------------------------------
# Serverless egress lockdown — serverless has NO internet egress.
#
# Creates a RESTRICTED_ACCESS network policy (ENFORCED, empty internet allowlist) and points
# the workspace at it, so serverless compute cannot reach the internet. NOTE: if serverless
# workloads need UC data on GCS, allowlist those buckets as STORAGE destinations (not modeled
# here — see the README); that is private access, not internet egress. To observe before
# enforcing, temporarily set egress_enforcement_mode = DRY_RUN.
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
