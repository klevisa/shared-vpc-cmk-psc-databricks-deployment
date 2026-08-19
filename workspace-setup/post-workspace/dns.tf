# -----------------------------------------------------------------------------
# The 4 A-records the PSC workspace needs, added to the Phase-1 private zone.
# workspace URL / dp- / psc-auth -> frontend IP; tunnel.<region> -> backend IP.
# The zone is authoritative for gcp.databricks.com inside the VPC, so these 4 are
# the complete set of resolvable names there.
# -----------------------------------------------------------------------------

locals {
  # workspace_url looks like https://1234567890.7.gcp.databricks.com
  workspace_num = regex("[0-9]+\\.[0-9]+", var.workspace_url)
}

resource "google_dns_record_set" "workspace_url" {
  project      = var.vpc_network_project_id
  managed_zone = var.private_zone_name
  name         = "${local.workspace_num}.${var.dns_name}"
  type         = "A"
  ttl          = 300
  rrdatas      = [var.frontend_pe_ip]
}

resource "google_dns_record_set" "workspace_dp" {
  project      = var.vpc_network_project_id
  managed_zone = var.private_zone_name
  name         = "dp-${local.workspace_num}.${var.dns_name}"
  type         = "A"
  ttl          = 300
  rrdatas      = [var.frontend_pe_ip]
}

resource "google_dns_record_set" "psc_auth" {
  project      = var.vpc_network_project_id
  managed_zone = var.private_zone_name
  name         = "${var.google_region}.psc-auth.${var.dns_name}"
  type         = "A"
  ttl          = 300
  rrdatas      = [var.frontend_pe_ip]
}

resource "google_dns_record_set" "relay_tunnel" {
  project      = var.vpc_network_project_id
  managed_zone = var.private_zone_name
  name         = "tunnel.${var.google_region}.${var.dns_name}"
  type         = "A"
  ttl          = 300
  rrdatas      = [var.backend_pe_ip]
}
