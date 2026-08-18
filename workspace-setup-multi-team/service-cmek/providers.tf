# Phase 2 — Cloud Security / KMS.
# Impersonates the SECURITY team's automation SA (cloudkms.admin on the SERVICE
# project). The runner needs iam.serviceAccountTokenCreator on that SA.
provider "google" {
  project                     = var.google_project_name
  region                      = var.google_region
  impersonate_service_account = var.google_service_account_email
}
