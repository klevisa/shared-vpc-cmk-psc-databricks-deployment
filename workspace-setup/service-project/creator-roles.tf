# -----------------------------------------------------------------------------
# Least-privilege WORKSPACE CREATOR role (SERVICE project). Owned by Cloud Foundation.
#
# The least-privilege GCP workspace-creation flow requires the workspace creator SA
# (databricks_account_admin_sa, the identity step 2.4 impersonates) to hold READ-ONLY
# roles so Databricks can validate settings during creation. For a Shared VPC there are
# TWO creator roles: this one on the SERVICE project, and a matching one on the HOST
# project (granted by the network team in step 2.2).
#
# This is NOT the workspace service account — that identity is minted by step 2.4 and
# gets its (create-capable) operator roles in steps 2.5-2.7.
#
# Source of truth for the exact permission list (re-verify in review):
#   https://docs.databricks.com/gcp/en/admin/cloud-configurations/gcp/permissions
#
# NOTE: creating a custom role needs roles/iam.roleAdmin on the target project — add it
# to the Foundation SA's standing roles (it is not implied by resourcemanager.projectIamAdmin).
# -----------------------------------------------------------------------------

resource "google_project_iam_custom_role" "ws_creator_service" {
  project     = google_project.service.project_id
  role_id     = "lpw.databricks.workspace.creator.service.v2"
  title       = "Databricks LPW workspace creator (service project)"
  description = "Read-only settings validation for least-privilege workspace creation."
  permissions = [
    "cloudkms.cryptoKeys.getIamPolicy",
    "compute.projects.get",
    "iam.roles.get",
    "iam.serviceAccounts.get",
    "iam.serviceAccounts.getIamPolicy",
    "resourcemanager.projects.get",
    "resourcemanager.projects.getIamPolicy",
    "serviceusage.services.get",
    "serviceusage.services.list",
  ]
}

resource "google_project_iam_member" "ws_creator_service" {
  project = google_project.service.project_id
  role    = google_project_iam_custom_role.ws_creator_service.id
  member  = "serviceAccount:${var.databricks_account_admin_sa}"
}
