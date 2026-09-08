# -----------------------------------------------------------------------------
# The Databricks WORKSPACE SA (created in step 2.4) launches cluster VMs, so it MUST be
# able to use the shared node subnet. Without this, clusters fail to start. This is the
# network team's "post-workspace handback".
#
# Least-privilege flow: instead of the broad predefined roles/compute.networkUser, we bind
# a custom NETWORK role (subnetworks.get + subnetworks.use) scoped to the node subnet.
# Source of truth for the permission list (re-verify in review):
#   https://docs.databricks.com/gcp/en/admin/cloud-configurations/gcp/sa-permissions
#
# NOTE: creating the custom role needs roles/iam.roleAdmin on the HOST project on the
# network SA (the same identity as step 2.2), in addition to compute.networkAdmin/dns.admin.
# -----------------------------------------------------------------------------

resource "google_project_iam_custom_role" "lpw_network" {
  project     = var.vpc_network_project_id
  role_id     = "lpw.databricks.network.role.v2"
  title       = "Databricks workspace SA network role"
  description = "Use the workspace's node subnet across the Shared VPC boundary."
  permissions = [
    "compute.subnetworks.get",
    "compute.subnetworks.use",
  ]
}

resource "google_compute_subnetwork_iam_member" "workspace_sa_network_user" {
  project    = var.vpc_network_project_id
  region     = var.google_region
  subnetwork = var.node_subnet_name
  role       = google_project_iam_custom_role.lpw_network.id
  member     = "serviceAccount:${var.gcp_workspace_sa}"
}
