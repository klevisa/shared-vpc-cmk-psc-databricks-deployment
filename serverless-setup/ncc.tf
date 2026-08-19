# -----------------------------------------------------------------------------
# Network Connectivity Config (NCC) — the anchor for serverless networking.
#
# Serverless compute does NOT run in your Shared VPC — it runs in Databricks-owned
# projects. The NCC governs how that serverless plane egresses and connects, and it
# gives the workspace STABLE, per-region Databricks project IDs — the same project
# numbers you source-pin the VPC-SC ingress to in ../data-access (see that config's
# `databricks_source_projects`). Create the NCC in the workspace's region, then bind it.
# -----------------------------------------------------------------------------

resource "databricks_mws_network_connectivity_config" "this" {
  provider = databricks.accounts
  name     = var.ncc_name
  region   = var.databricks_region
}

# Attach the NCC to the workspace. One NCC per workspace; re-binding overwrites.
resource "databricks_mws_ncc_binding" "this" {
  provider                       = databricks.accounts
  network_connectivity_config_id = databricks_mws_network_connectivity_config.this.network_connectivity_config_id
  workspace_id                   = var.workspace_id
}
