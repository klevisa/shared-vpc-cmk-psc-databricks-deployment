# Handoff → step 2.4 (workspace) registers both; step 2.7 (cmek-workspace-grant) grants the
# workspace SA on the managed-services key.
output "storage_cmek_key_id" {
  value       = google_kms_crypto_key.storage.id
  description = "Full KMS resource id of the STORAGE key (workspace buckets + disks)."
}
output "managed_services_cmek_key_id" {
  value       = google_kms_crypto_key.managed_services.id
  description = "Full KMS resource id of the MANAGED_SERVICES key (control-plane data)."
}
