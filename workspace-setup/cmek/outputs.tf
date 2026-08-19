# Handoff → consumed by step 2.4 (workspace) as var.cmek_key_id.
output "cmek_key_id" {
  value       = google_kms_crypto_key.key.id
  description = "Full KMS resource id: projects/<svc>/locations/<region>/keyRings/<kr>/cryptoKeys/<key>"
}
