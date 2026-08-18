# -----------------------------------------------------------------------------
# The Databricks WORKSPACE SA (created in Phase 3) launches cluster VMs, so it
# MUST hold compute.networkUser on the shared node subnet. Without this, clusters
# fail to start. This is the "post-workspace handback" to the network team.
# -----------------------------------------------------------------------------

resource "google_compute_subnetwork_iam_member" "workspace_sa_network_user" {
  project    = var.vpc_network_project_id
  region     = var.google_region
  subnetwork = var.node_subnet_name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${var.gcp_workspace_sa}"
}
