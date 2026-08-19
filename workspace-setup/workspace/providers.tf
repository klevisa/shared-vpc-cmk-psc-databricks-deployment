# step 2.4 — Data / Databricks Platform.
# Talks ONLY to the Databricks account API, authenticating by impersonating the
# Data Platform team's SA (which is a Databricks ACCOUNT ADMIN). No google
# provider is needed here — no GCP resources are created in this phase, so this
# config never touches the private workspace endpoint.
provider "databricks" {
  alias                  = "accounts"
  host                   = "https://accounts.gcp.databricks.com"
  account_id             = var.databricks_account_id
  google_service_account = var.google_service_account_email
}
