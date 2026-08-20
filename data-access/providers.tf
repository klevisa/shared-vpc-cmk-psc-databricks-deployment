# Catalog setup runs AFTER the workspace exists. It spans several teams, so each
# responsibility is an aliased provider impersonating that team's own SA — least
# privilege holds even though it's one config. Each runner needs
# roles/iam.serviceAccountTokenCreator on the SA it impersonates.
#
# Databricks — two identities:
#   accounts : the ACCOUNT ADMIN (a GCP SA impersonated for the account API) — grants the
#              catalog automation SP the scoped metastore CREATE privileges.
#   uc_admin : the CATALOG AUTOMATION SP — a native Databricks service principal (OAuth M2M:
#              client_id = its application id, client_secret = its OAuth secret). Creates and
#              owns the storage credentials, external locations, catalogs, schemas against the
#              WORKSPACE API. It is NOT a metastore admin; it holds only CREATE_*.
#
# GCP — three identities (map to whichever Yahoo teams own each):
#   perimeter   : Cloud/Network Security — adds the VPC-SC ingress rules.
#   data_bucket     : owner of your existing data bucket — grants read-only IAM.
#   analytics_bucket: Data Platform — creates the analytics data bucket + grants read-write IAM.
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
  alias         = "uc_admin"
  host          = var.workspace_url
  client_id     = var.catalog_automation_sp # the SP's application id (OAuth M2M)
  client_secret = var.catalog_automation_client_secret
}

provider "google" {
  alias                       = "perimeter"
  project                     = var.analytics_bucket_project # quota/context only
  impersonate_service_account = var.perimeter_sa
}

provider "google" {
  alias                       = "data_bucket"
  project                     = var.readonly_bucket_project
  impersonate_service_account = var.data_bucket_sa
}

provider "google" {
  alias                       = "analytics_bucket"
  project                     = var.analytics_bucket_project
  impersonate_service_account = var.analytics_bucket_sa
}
