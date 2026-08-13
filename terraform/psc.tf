# -----------------------------------------------------------------------------
# PSC endpoints — allocated in the HOST project's PSC subnet, targeting the
# Databricks service attachments. Frontend = UI/REST (443); backend = SCC relay
# (6666). Both must reach ACCEPTED before the workspace is usable.
# -----------------------------------------------------------------------------

resource "google_compute_address" "frontend_pe_ip" {
  provider     = google-beta
  name         = var.workspace_pe_ip_name
  project      = var.vpc_network_project_id
  region       = var.google_region
  subnetwork   = google_compute_subnetwork.pe_subnet.id
  address_type = "INTERNAL"
}

resource "google_compute_address" "backend_pe_ip" {
  provider     = google-beta
  name         = var.relay_pe_ip_name
  project      = var.vpc_network_project_id
  region       = var.google_region
  subnetwork   = google_compute_subnetwork.pe_subnet.id
  address_type = "INTERNAL"
}

resource "google_compute_forwarding_rule" "frontend_psc_ep" {
  name                  = var.workspace_pe
  project               = var.vpc_network_project_id
  region                = var.google_region
  network               = google_compute_network.vpc.id
  ip_address            = google_compute_address.frontend_pe_ip.id
  target                = var.workspace_service_attachment
  load_balancing_scheme = "" # required empty when target is a service attachment
}

resource "google_compute_forwarding_rule" "backend_psc_ep" {
  name                  = var.relay_pe
  project               = var.vpc_network_project_id
  region                = var.google_region
  network               = google_compute_network.vpc.id
  ip_address            = google_compute_address.backend_pe_ip.id
  target                = var.relay_service_attachment
  load_balancing_scheme = ""
}

output "front_end_psc_status" {
  value = "Frontend PSC status: ${google_compute_forwarding_rule.frontend_psc_ep.psc_connection_status}"
}

output "backend_psc_status" {
  value = "Backend PSC status: ${google_compute_forwarding_rule.backend_psc_ep.psc_connection_status}"
}
