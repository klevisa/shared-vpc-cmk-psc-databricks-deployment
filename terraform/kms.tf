# -----------------------------------------------------------------------------
# CMEK key — created in the SERVICE project (where the workspace's GCE disks and
# GCS buckets live, so its service agents are the ones that encrypt with it).
#
# STORAGE use case  -> grant the SERVICE project's Google-managed service agents:
#     service-<SERVICE_PROJNUM>@compute-system.iam.gserviceaccount.com  (VM disks)
#     service-<SERVICE_PROJNUM>@gs-project-accounts.iam.gserviceaccount.com (GCS)
# MANAGED_SERVICES  -> Databricks auto-grants its own SA on key registration.
# -----------------------------------------------------------------------------

resource "google_kms_key_ring" "ring" {
  name     = var.kms_keyring_name
  project  = var.google_project_name
  location = var.google_region
}

resource "google_kms_crypto_key" "key" {
  name            = var.kms_key_name
  key_ring        = google_kms_key_ring.ring.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s" # 90 days
}

locals {
  cmek_resource_id = google_kms_crypto_key.key.id

  storage_service_agents = [
    "serviceAccount:service-${var.google_service_project_number}@compute-system.iam.gserviceaccount.com",
    "serviceAccount:service-${var.google_service_project_number}@gs-project-accounts.iam.gserviceaccount.com",
  ]
}

resource "google_kms_crypto_key_iam_member" "storage_agents" {
  for_each      = toset(local.storage_service_agents)
  crypto_key_id = google_kms_crypto_key.key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = each.value
}
