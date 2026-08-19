# -----------------------------------------------------------------------------
# Attach the new service project to the (existing) Shared VPC host. The host has
# been a Shared VPC host for a long time, so only the attachment is managed here.
# Requires roles/compute.xpnAdmin at the org/folder. Downstream phases assume this
# attachment exists.
# -----------------------------------------------------------------------------

resource "google_compute_shared_vpc_service_project" "service" {
  host_project    = var.vpc_network_project_id
  service_project = google_project.service.project_id
  depends_on      = [google_project_service.service]
}
