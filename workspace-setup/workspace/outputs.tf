# Handoff → consumed by step 2.5 (post-workspace).
output "workspace_id" { value = databricks_mws_workspaces.this.workspace_id }
output "workspace_url" { value = databricks_mws_workspaces.this.workspace_url }
output "gcp_workspace_sa" {
  value       = databricks_mws_workspaces.this.gcp_workspace_sa
  description = "db-<workspace-id>@prod-gcp-<region> — step 2.5 grants this networkUser on the host subnet so clusters can launch."
}
output "metastore_assignment" {
  value = databricks_metastore_assignment.this.metastore_id
}
