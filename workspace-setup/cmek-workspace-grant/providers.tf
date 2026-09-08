# step 2.7 — Cloud Security / KMS handback.
# Same team/identity as step 2.3 (SERVICE-project cloudkms.admin). Runs AFTER the
# workspace exists (step 2.4) to grant the workspace SA encrypt/decrypt on the CMEK
# key for the MANAGED_SERVICES use case. The key's IAM is owned by Security, so this
# grant must run as the Security SA — not the network SA that owns step 2.6.
provider "google" {
  project                     = var.google_project_name
  region                      = var.google_region
  impersonate_service_account = var.google_service_account_email
}
