# -----------------------------------------------------------------------------
# Private DNS ZONE only (HOST project). The 4 A-records are added in Phase 4,
# because they need the workspace URL (Phase 3) and the PE IPs (this phase).
# The zone is authoritative for gcp.databricks.com INSIDE the VPC.
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
}
