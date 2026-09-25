# -----------------------------------------------------------------------------
# STATIC Shared VPC subnet grant — the SERVICE project's Compute Engine service agent
# needs networkUser on the HOST node subnet to place cluster VMs on the Shared VPC (a
# GCP Shared VPC requirement). It needs only the service project number (no workspace),
# so it belongs to step 2.2.
#
# The Databricks WORKSPACE SA grant is NOT here — that SA doesn't exist until the
# workspace is created (step 2.4), so its network role (step 2.6) is the only other
# identity granted on the subnet.
# -----------------------------------------------------------------------------

resource "google_compute_subnetwork_iam_member" "compute_agent_subnet_user" {
  project    = var.vpc_network_project_id
  region     = var.google_region
  subnetwork = google_compute_subnetwork.node_subnet.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:service-${var.google_service_project_number}@compute-system.iam.gserviceaccount.com"
}
