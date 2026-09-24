# Serverless setup runs AFTER the workspace exists (step 2.4). Everything here is the
# Databricks ACCOUNT API — the Network Connectivity Config, its workspace binding, and
# the optional serverless egress network policy are all account-level objects. So there
# is a single provider: the account-admin SP, authenticating via OAuth M2M. No GCP
# resources are created in this config.
provider "databricks" {
  alias         = "accounts"
  host          = "https://accounts.gcp.databricks.com"
  account_id    = var.databricks_account_id
  client_id     = var.account_admin_sp # account-admin SP application id (OAuth M2M)
  client_secret = var.account_admin_sp_client_secret
}
