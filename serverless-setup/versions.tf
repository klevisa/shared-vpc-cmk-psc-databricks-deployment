terraform {
  required_version = ">= 1.5.0"
  required_providers {
    # >= 1.116 for databricks_account_network_policy / databricks_workspace_network_option
    # (the optional egress lockdown). NCC + binding are older; this floor covers both.
    databricks = { source = "databricks/databricks", version = ">= 1.116.0" }
  }
}
