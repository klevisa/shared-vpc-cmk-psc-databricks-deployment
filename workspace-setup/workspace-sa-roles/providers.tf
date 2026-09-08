# step 2.5 — Cloud IAM.
# Grants the Databricks workspace SA (minted by step 2.4) its operator roles on the
# SERVICE project, so it can create the workspace's GCS/GCE resources when step 2.8
# finalizes the workspace. Impersonates a Cloud IAM SA that holds roles/iam.roleAdmin +
# roles/resourcemanager.projectIamAdmin on the SERVICE project. Runs AFTER step 2.4.
provider "google" {
  project                     = var.google_project_name
  region                      = var.google_region
  impersonate_service_account = var.google_service_account_email
}
