# -----------------------------------------------------------------------------
# CMEK key in the SERVICE project. Owned by Cloud Security / KMS.
# This step makes only the STORAGE-use-case grants. Grant the SERVICE project's
# Google-managed agents here:
#     service-<num>@compute-system   (VM disks)
#     service-<num>@gs-project-accounts (GCS)
# MANAGED_SERVICES  -> granted to the workspace SA in step 2.7, once the SA exists.
#   In a least-privilege deployment Databricks does NOT auto-grant itself (the step-2.4
#   key registration only calls the account API and never touches the key's IAM).
#
# NOTE: the service agents must already exist (Cloud Foundation, step 2.1) or these
# grants fail with 400 "does not exist".
# -----------------------------------------------------------------------------

resource "google_kms_key_ring" "ring" {
  name     = var.kms_keyring_name
  project  = var.google_project_name
  location = var.google_region

  # Key access is data access, and a lost key bricks all workspace data. Block a stray
  # terraform destroy from targeting the ring. Key rings are not deletable in GCP anyway.
  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key" "key" {
  name            = var.kms_key_name
  key_ring        = google_kms_key_ring.ring.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s" # 90 days

  # 30-day recovery window: a scheduled key-version destruction can be cancelled within
  # this window before the material is gone. Pair with prevent_destroy so terraform can't
  # remove the key itself.
  destroy_scheduled_duration = "2592000s" # 30 days

  lifecycle {
    prevent_destroy = true
  }
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

  # PoC time-box: self-expires at var.poc_expiry via a request.time IAM condition. After
  # expiry the service agents can no longer encrypt/decrypt with this key, so VM disks and
  # GCS objects can't be served — the intended teardown effect. Keep poc_expiry deliberate.
  condition {
    title       = "poc-expiry"
    description = "Auto-expire this PoC grant after the PoC end date."
    expression  = "request.time < timestamp(\"${var.poc_expiry}\")"
  }
}
