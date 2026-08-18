# Catalog setup runs AFTER the workspace exists. It spans several teams, so each
# responsibility is an aliased provider impersonating that team's own SA — least
# privilege holds even though it's one config. Each runner needs
# roles/iam.serviceAccountTokenCreator on the SA it impersonates.
#
# Databricks — two identities:
#   accounts : the ACCOUNT ADMIN (from prereqs) — grants the automation SA the scoped
#              metastore CREATE privileges.
#   uc_admin : the CATALOG AUTOMATION SA (manually created + registered by the account
#              admin) — creates and owns the storage credentials, external locations,
#              catalogs, schemas. It is NOT a metastore admin; it holds only CREATE_*.
#
# GCP — three identities (map to whichever Yahoo teams own each):
#   perimeter   : Cloud/Network Security — adds the VPC-SC ingress rules.
#   data_bucket : owner of the customer's existing data bucket — grants read-only IAM.
#   poc_bucket  : Data Platform — creates the PoC data bucket + grants read-write IAM.
#
# NOTE: Unity Catalog objects are created against the WORKSPACE API. If the workspace is
# private (public_access_enabled = false), run this from somewhere that can reach the
# workspace endpoint (inside or peered to the VPC).

provider "databricks" {
  alias                  = "accounts"
  host                   = "https://accounts.gcp.databricks.com"
  account_id             = var.databricks_account_id
  google_service_account = var.account_admin_sa
}

provider "databricks" {
  alias                  = "uc_admin"
  host                   = var.workspace_url
  google_service_account = var.catalog_automation_sa
}

provider "google" {
  alias                       = "perimeter"
  project                     = var.poc_bucket_project # quota/context only
  impersonate_service_account = var.perimeter_sa
}

provider "google" {
  alias                       = "data_bucket"
  project                     = var.readonly_bucket_project
  impersonate_service_account = var.data_bucket_sa
}

provider "google" {
  alias                       = "poc_bucket"
  project                     = var.poc_bucket_project
  impersonate_service_account = var.poc_bucket_sa
}
