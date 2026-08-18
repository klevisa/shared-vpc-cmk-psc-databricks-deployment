# Catalog setup runs AFTER the workspace exists. It uses two impersonated identities so
# least-privilege holds even though this is one config:
#   - databricks (workspace provider): the Data Platform SA (Unity Catalog / metastore
#     admin) — creates the storage credentials, external locations, catalogs, schemas.
#   - google: the Security SA — grants bucket IAM and adds the VPC-SC ingress policies.
# Each runner needs roles/iam.serviceAccountTokenCreator on the SA it impersonates.
#
# NOTE: Unity Catalog objects are created against the WORKSPACE API. If the workspace is
# private (public_access_enabled = false), run this from somewhere that can reach the
# workspace endpoint (inside or peered to the VPC).
provider "databricks" {
  alias                  = "workspace"
  host                   = var.workspace_url
  google_service_account = var.databricks_service_account_email
}

provider "google" {
  project                     = var.google_project
  impersonate_service_account = var.gcp_service_account_email
}
