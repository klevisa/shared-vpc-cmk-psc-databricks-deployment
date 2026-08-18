# -----------------------------------------------------------------------------
# The Shared VPC relationship between the (existing) host project and the new
# service project: enable the host, then attach the service project. Requires
# roles/compute.xpnAdmin at the org/folder. Downstream phases assume this exists.
# -----------------------------------------------------------------------------

resource "google_compute_shared_vpc_host_project" "host" {
  project    = var.vpc_network_project_id
  depends_on = [google_project_service.host]
}

resource "google_compute_shared_vpc_service_project" "service" {
  host_project    = var.vpc_network_project_id
  service_project = google_project.service.project_id
  depends_on = [
    google_compute_shared_vpc_host_project.host,
    google_project_service.service,
  ]
}
