# Handoff → consumed by steps 2.5 (workspace-sa-roles), 2.6 (post-workspace), 2.7 (cmek grant).
# Available after the PHASE 1 apply (finalize=false); workspace_url populates once RUNNING.
output "workspace_id" { value = databricks_mws_workspaces.this.workspace_id }
output "workspace_url" { value = databricks_mws_workspaces.this.workspace_url }
output "gcp_workspace_sa" {
  value       = databricks_mws_workspaces.this.gcp_workspace_sa
  description = "db-<workspace-id>@prod-gcp-<region> — steps 2.5-2.7 grant this its operator roles (project/resource on the service project, network on the subnet, CMEK) so it can provision and run the workspace."
}
output "metastore_assignment" {
  value       = try(databricks_metastore_assignment.this[0].metastore_id, null)
  description = "Set only after PHASE 2 (finalize=true); null during phase 1."
}
