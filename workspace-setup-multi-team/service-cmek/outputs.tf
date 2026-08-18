# Handoff → consumed by Phase 3 (databricks-account) as var.cmek_key_id.
output "cmek_key_id" {
  value       = google_kms_crypto_key.key.id
  description = "Full KMS resource id: projects/<svc>/locations/<region>/keyRings/<kr>/cryptoKeys/<key>"
}
