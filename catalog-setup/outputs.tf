output "metastore_admin_group" {
  value       = databricks_group.metastore_admins.display_name
  description = "The regional metastore-admin group created here (the specified SA is a member)."
}
output "poc_data_bucket" {
  value       = google_storage_bucket.poc.name
  description = "The PoC data bucket created here (backs the read-write catalog)."
}
output "readonly_catalog" {
  value = databricks_catalog.ro.name
}
output "readwrite_catalog" {
  value = databricks_catalog.rw.name
}
output "readonly_storage_credential_sa" {
  value       = databricks_storage_credential.ro.databricks_gcp_service_account[0].email
  description = "Generated Databricks SA granted read-only on the data bucket (and named in the VPC-SC ingress)."
}
output "readwrite_storage_credential_sa" {
  value       = databricks_storage_credential.rw.databricks_gcp_service_account[0].email
  description = "Generated Databricks SA granted read-write on the PoC data bucket (and named in the VPC-SC ingress)."
}
