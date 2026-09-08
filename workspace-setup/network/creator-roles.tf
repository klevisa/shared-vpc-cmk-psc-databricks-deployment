# -----------------------------------------------------------------------------
# Least-privilege WORKSPACE CREATOR role (HOST project). Owned by Network Engineering.
#
# The Shared VPC least-privilege flow needs the workspace creator SA
# (databricks_account_admin_sa, impersonated by step 2.4) to READ host-project network
# settings during creation. This is the host-side half of the creator grant; the
# service-side half is in step 2.1 (service-project/creator-roles.tf).
#
# Source of truth for the exact permission list (re-verify in review):
#   https://docs.databricks.com/gcp/en/admin/cloud-configurations/gcp/permissions
#
# NOTE: creating a custom role needs roles/iam.roleAdmin on the HOST project — add it to
# the network SA's standing roles (compute.networkAdmin/securityAdmin/dns.admin don't imply it).
# -----------------------------------------------------------------------------

resource "google_project_iam_custom_role" "ws_creator_host" {
  project     = var.vpc_network_project_id
  role_id     = "lpw.databricks.workspace.creator.host.v2"
  title       = "Databricks LPW workspace creator (host project)"
  description = "Read-only host-network validation for least-privilege workspace creation."
  permissions = [
    "compute.forwardingRules.get",
    "compute.forwardingRules.list",
    "compute.networks.get",
    "compute.projects.get",
    "compute.subnetworks.get",
    "compute.subnetworks.getIamPolicy",
    "iam.roles.get",
    "resourcemanager.projects.get",
    "resourcemanager.projects.getIamPolicy",
    "serviceusage.services.get",
    "serviceusage.services.list",
  ]
}

resource "google_project_iam_member" "ws_creator_host" {
  project = var.vpc_network_project_id
  role    = google_project_iam_custom_role.ws_creator_host.id
  member  = "serviceAccount:${var.databricks_account_admin_sa}"
}
