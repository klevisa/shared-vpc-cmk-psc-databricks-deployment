# -----------------------------------------------------------------------------
# CMEK key in the SERVICE project. Owned by Cloud Security / KMS.
# STORAGE use case  -> grant the SERVICE project's Google-managed agents here:
#     service-<num>@compute-system   (VM disks)
#     service-<num>@gs-project-accounts (GCS)
# MANAGED_SERVICES  -> Databricks auto-grants its own SA at registration (step 2.4).
#
# NOTE: the service agents must already exist (Cloud Foundation, step 2.1) or these
# grants fail with 400 "does not exist".
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
