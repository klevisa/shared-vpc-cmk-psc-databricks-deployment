# -----------------------------------------------------------------------------
# Providers — Shared VPC model
#
# Two GCP projects are in play (see README):
#   - HOST project    (var.vpc_network_project_id): owns the VPC, subnets,
#     firewall, PSC endpoints, and private DNS.
#   - SERVICE project (var.google_project_name): where the Databricks workspace's
#     GCE/GCS resources live, plus the CMEK key.
#
# A single google / google-beta provider is used; host-project resources set
# `project = var.vpc_network_project_id` explicitly to place them in the host.
#
# Databricks account + workspace auth uses Google service-account IMPERSONATION
# (var.google_service_account_email). That SA must be:
#   - an account admin on the Databricks account,
#   - Owner (or the granular equivalent) on the SERVICE project,
#   - compute.networkUser + compute.networkViewer on the HOST project,
# and the caller running Terraform must have Token Creator on that SA.
# (Impersonation lets the workspace-scoped provider authenticate to a brand-new
#  workspace without a browser login — see service-account note in README.)
# -----------------------------------------------------------------------------

provider "google" {
  project = var.google_project_name # service project (default target)
  region  = var.google_region
}

provider "google-beta" {
  project = var.google_project_name
  region  = var.google_region
}

provider "databricks" {
  alias                  = "accounts"
  host                   = "https://accounts.gcp.databricks.com"
  account_id             = var.databricks_account_id
  google_service_account = var.google_service_account_email
}

provider "databricks" {
  alias                  = "workspace"
  host                   = databricks_mws_workspaces.this.workspace_url
  google_service_account = var.google_service_account_email
}
