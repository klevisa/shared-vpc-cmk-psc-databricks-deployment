# Phase 1 — Network Engineering.
# Impersonates the NETWORK team's automation SA (host-project network admin).
# The runner needs roles/iam.serviceAccountTokenCreator on that SA.
provider "google" {
  project                     = var.vpc_network_project_id
  region                      = var.google_region
  impersonate_service_account = var.google_service_account_email
}

provider "google-beta" {
  project                     = var.vpc_network_project_id
  region                      = var.google_region
  impersonate_service_account = var.google_service_account_email
}
