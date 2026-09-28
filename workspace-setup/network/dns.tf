# -----------------------------------------------------------------------------
# Private DNS ZONE only (HOST project). The 4 A-records are added in step 2.6,
# because they need the workspace URL (step 2.4) and the PE IPs (this phase).
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

# -----------------------------------------------------------------------------
# Private Google Access via the restricted VIP: resolve *.googleapis.com to the
# restricted VIP inside the VPC, paired with the google_apis_vip route (network.tf) and the
# egress lockdown, so all Google-API traffic (GCS, KMS, BigQuery, Storage Transfer) lands in
# one /30. The four A-record IPs are the restricted.googleapis.com VIP.
# -----------------------------------------------------------------------------
resource "google_dns_managed_zone" "googleapis" {
  name        = "${var.private_zone_name}-googleapis"
  project     = var.vpc_network_project_id
  dns_name    = "googleapis.com."
  description = "Restricted Private Google Access for googleapis.com (VPC-internal)"
  visibility  = "private"
  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc.id
    }
  }
}

resource "google_dns_record_set" "restricted_a" {
  project      = var.vpc_network_project_id
  managed_zone = google_dns_managed_zone.googleapis.name
  name         = "restricted.googleapis.com."
  type         = "A"
  ttl          = 300
  rrdatas      = ["199.36.153.4", "199.36.153.5", "199.36.153.6", "199.36.153.7"]
}

resource "google_dns_record_set" "googleapis_cname" {
  project      = var.vpc_network_project_id
  managed_zone = google_dns_managed_zone.googleapis.name
  name         = "*.googleapis.com."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["restricted.googleapis.com."]
}
