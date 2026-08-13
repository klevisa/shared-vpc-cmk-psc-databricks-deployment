output "workspace_url" {
  value = databricks_mws_workspaces.this.workspace_url
}

output "workspace_id" {
  value = databricks_mws_workspaces.this.workspace_id
}

output "host_project" {
  value = var.vpc_network_project_id
}

output "service_project" {
  value = var.google_project_name
}

output "frontend_pe_ip" {
  value = google_compute_address.frontend_pe_ip.address
}

output "backend_pe_ip" {
  value = google_compute_address.backend_pe_ip.address
}

output "metastore_assignment" {
  value = var.metastore_id != "" ? databricks_metastore_assignment.this[0].metastore_id : "none (relying on auto-assignment)"
}
