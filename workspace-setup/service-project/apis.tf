# -----------------------------------------------------------------------------
# Enable the required APIs on the SERVICE project (created here). GCP services are
# off by default — downstream phases can't create a KMS key, DNS zone, PSC endpoint,
# etc. until the owning API is enabled. Enabling the Compute API also provisions the
# project's compute service agent (service-<num>@compute-system), which step 2.3's
# CMEK grant depends on.
#
# The host project's APIs (compute, dns) are already enabled — it has been a Shared
# VPC host for a long time — so nothing is enabled on it here.
# -----------------------------------------------------------------------------

resource "google_project_service" "service" {
  for_each           = toset(var.service_project_apis)
  project            = google_project.service.project_id
  service            = each.value
  disable_on_destroy = false
}
