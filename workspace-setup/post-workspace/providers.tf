# step 2.5 — Network / Cloud IAM handback.
# Same team/identity as step 2.2 (host-project network admin). Runs AFTER the
# workspace exists (step 2.4) to grant the workspace SA on the host subnet and add
# the DNS records.
provider "google" {
  project                     = var.vpc_network_project_id
  region                      = var.google_region
  impersonate_service_account = var.google_service_account_email
}
