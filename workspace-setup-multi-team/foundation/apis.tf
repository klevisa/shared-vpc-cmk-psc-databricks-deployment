# -----------------------------------------------------------------------------
# Enable the required APIs on both projects. GCP services are off by default —
# downstream phases can't create a KMS key, DNS zone, PSC endpoint, etc. until the
# owning API is enabled. Enabling the Compute API also provisions the project's
# compute service agent (service-<num>@compute-system), which Phase 2's CMEK grant
# depends on.
# -----------------------------------------------------------------------------

resource "google_project_service" "host" {
  for_each           = toset(var.host_project_apis)
  project            = var.vpc_network_project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_project_service" "service" {
  for_each           = toset(var.service_project_apis)
  project            = google_project.service.project_id
  service            = each.value
  disable_on_destroy = false
}
