# -----------------------------------------------------------------------------
# Private DNS (HOST project) — makes the workspace hostnames resolve to the
# private PSC IPs, but only inside the Shared VPC. Created after the workspace so
# its id can be extracted for the per-workspace records.
#
# The zone is authoritative for gcp.databricks.com INSIDE the VPC: any name under
# that domain not defined here returns NXDOMAIN from inside the VPC, so the 4
# records below are the complete set a PSC workspace needs.
# -----------------------------------------------------------------------------

resource "google_dns_managed_zone" "private" {
  name        = var.private_zone_name
  project     = var.vpc_network_project_id
  dns_name    = var.dns_name
  description = "Databricks private DNS zone (PSC)"
  visibility  = "private"
  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc.id
    }
  }
  depends_on = [databricks_mws_workspaces.this]
}

locals {
  # workspace_url looks like https://1234567890.7.gcp.databricks.com
  workspace_num = regex("[0-9]+\\.[0-9]+", databricks_mws_workspaces.this.workspace_url)
}

resource "google_dns_record_set" "workspace_url" {
  project      = var.vpc_network_project_id
  managed_zone = google_dns_managed_zone.private.name
  name         = "${local.workspace_num}.${google_dns_managed_zone.private.dns_name}"
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.frontend_pe_ip.address]
}

resource "google_dns_record_set" "workspace_dp" {
  project      = var.vpc_network_project_id
  managed_zone = google_dns_managed_zone.private.name
  name         = "dp-${local.workspace_num}.${google_dns_managed_zone.private.dns_name}"
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.frontend_pe_ip.address]
}

resource "google_dns_record_set" "psc_auth" {
  project      = var.vpc_network_project_id
  managed_zone = google_dns_managed_zone.private.name
  name         = "${var.google_region}.psc-auth.${google_dns_managed_zone.private.dns_name}"
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.frontend_pe_ip.address]
}

resource "google_dns_record_set" "relay_tunnel" {
  project      = var.vpc_network_project_id
  managed_zone = google_dns_managed_zone.private.name
  name         = "tunnel.${var.google_region}.${google_dns_managed_zone.private.dns_name}"
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.backend_pe_ip.address]
}
