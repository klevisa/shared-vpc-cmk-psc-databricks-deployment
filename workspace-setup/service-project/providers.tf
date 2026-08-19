# step 2.1 — Cloud Foundation / Landing Zone.
# Impersonates the FOUNDATION team's SA, which holds org/folder-level standing:
# create projects, link billing, and manage the Shared VPC (xpnAdmin). The runner
# needs roles/iam.serviceAccountTokenCreator on that SA.
#
# No default `project` is set — this config creates a project and operates on two
# projects by explicit argument. If a data call needs a quota project, set
# `billing_project` + `user_project_override` to the existing host project.
provider "google" {
  region                      = var.google_region
  impersonate_service_account = var.google_service_account_email
}

provider "google-beta" {
  region                      = var.google_region
  impersonate_service_account = var.google_service_account_email
}
