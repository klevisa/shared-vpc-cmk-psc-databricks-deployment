# Serverless setup runs AFTER the workspace exists (step 2.4). Everything here is the
# Databricks ACCOUNT API — the Network Connectivity Config, its workspace binding, and
# the optional serverless egress network policy are all account-level objects. So there
# is a single provider: the account admin, authenticating by impersonating the Data
# Platform SA. No GCP resources are created in this config.
provider "databricks" {
  alias                  = "accounts"
  host                   = "https://accounts.gcp.databricks.com"
  account_id             = var.databricks_account_id
  google_service_account = var.account_admin_sa
}
