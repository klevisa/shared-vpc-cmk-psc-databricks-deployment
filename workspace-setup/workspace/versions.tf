terraform {
  required_version = ">= 1.5.0"
  required_providers {
    # >= 1.95.0 for expected_workspace_status on databricks_mws_workspaces
    # (the least-privilege two-phase create→grant→run flow). Added 2025-10-23.
    databricks = { source = "databricks/databricks", version = ">= 1.95.0" }
    random     = { source = "hashicorp/random", version = ">= 3.5.0" }
  }
}
