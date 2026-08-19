# Handoff → consumed by step 2.2 (network) and steps 2.3/2.4 (service project).
output "host_project" {
  value = var.vpc_network_project_id
}
output "service_project_id" {
  value       = google_project.service.project_id
  description = "→ step 2.3 & 3 google_project_name."
}
output "service_project_number" {
  value       = google_project.service.number
  description = "→ step 2.2 & 2 google_service_project_number (service-agent emails)."
}
output "gcs_service_agent" {
  value       = data.google_storage_project_service_account.gcs.email_address
  description = "The GCS service agent step 2.3 grants CMEK access to."
}
