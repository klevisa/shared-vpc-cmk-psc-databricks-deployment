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
# Databricks ACCOUNT auth uses Google service-account IMPERSONATION
# (var.google_service_account_email). That SA must be:
#   - an account admin on the Databricks account,
#   - Owner (or the granular equivalent) on the SERVICE project,
#   - compute.networkUser + compute.networkViewer on the HOST project,
# and the caller running Terraform must have Token Creator on that SA.
# (This template talks ONLY to the account API — accounts.gcp.databricks.com —
#  so it never needs to reach the private workspace endpoint. A delegated
#  workspace admin, if you want one, is assigned over the account API too; see
#  the note in databricks.tf.)
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
