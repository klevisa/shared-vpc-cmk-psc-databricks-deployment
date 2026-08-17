# -----------------------------------------------------------------------------
# STATIC Shared VPC subnet grants — the SERVICE project's own compute identities
# must be allowed to place VMs on the HOST node subnet. These need only the
# service project number (no workspace), so they belong to Phase 1.
#
# The Databricks WORKSPACE SA grant is NOT here — that SA doesn't exist until the
# workspace is created (Phase 3), so its networkUser grant is Phase 4.
# -----------------------------------------------------------------------------

locals {
  service_project_network_users = [
    "serviceAccount:${var.google_service_project_number}@cloudservices.gserviceaccount.com",
    "serviceAccount:service-${var.google_service_project_number}@compute-system.iam.gserviceaccount.com",
  ]
}

resource "google_compute_subnetwork_iam_member" "shared_subnet_users" {
  for_each   = toset(local.service_project_network_users)
  project    = var.vpc_network_project_id
  region     = var.google_region
  subnetwork = google_compute_subnetwork.node_subnet.name
  role       = "roles/compute.networkUser"
  member     = each.value
}
