# steps 2.4 (create, finalize=false) & 2.8 (finalize, finalize=true) — Data / Databricks Platform.
# Talks ONLY to the Databricks account API, authenticating by impersonating the
# databricks_account_admin_sa (a GCP SA registered as a Databricks account-admin user).
# No google provider is needed here — this config creates no GCP resources directly and
# never touches the private workspace endpoint.
#
# NOTE: databricks_account_admin_sa is the least-privilege workspace CREATOR. It is NOT
# GCP-role-free: it must hold the read-only creator custom roles on the service project
# (granted in step 2.1) and the host project (step 2.2) so Databricks can validate settings
# during creation. The workspace SA that Databricks mints does the actual resource creation,
# and gets its operator roles in steps 2.5-2.7.
provider "databricks" {
  alias                  = "accounts"
  host                   = "https://accounts.gcp.databricks.com"
  account_id             = var.databricks_account_id
  google_service_account = var.databricks_account_admin_sa
}
