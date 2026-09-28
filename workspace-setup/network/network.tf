# -----------------------------------------------------------------------------
# VPC + subnets inside the EXISTING host project. Owned by Network Engineering.
#
# The host project is a long-standing Shared VPC host; Cloud Foundation attached the
# service project to it in step 2.1. This config only creates the VPC and its subnets
# within that host project.
# Records for the DNS zone are added in step 2.6 (post-workspace).
# -----------------------------------------------------------------------------

# ---- VPC + subnets ----
resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  project                 = var.vpc_network_project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "node_subnet" {
  name                     = var.node_subnet_name
  project                  = var.vpc_network_project_id
  ip_cidr_range            = var.node_subnet_cidr
  region                   = var.google_region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true # NPIP nodes reach GCS/KMS via Private Google Access
}

resource "google_compute_subnetwork" "pe_subnet" {
  name          = var.pe_subnet_name
  project       = var.vpc_network_project_id
  ip_cidr_range = var.pe_subnet_cidr
  region        = var.google_region
  network       = google_compute_network.vpc.id
  purpose       = "PRIVATE"
}

# ---- Egress ----
# Default-deny outbound, made explicit and tamper-evident (there is no NAT and no public IP,
# so nodes can't reach the internet today; this rule keeps it that way if a NAT or external
# IP is ever added). The only egress a node needs is: (1) internal — node<->node Spark and
# node->PSC endpoints; (2) Google APIs via the restricted Private Google Access VIP. The
# Databricks control plane/relay are reached over PSC (endpoint subnet), not internet egress.
# This assumes clusters pull NO public packages (PyPI/npm/Maven) — if they must, add an
# allowlisted path or private mirrors before relying on the deny rule.

# Route Google-API traffic to the restricted VIP (paired with the googleapis.com DNS zone in
# dns.tf) so all Google-API egress lands in one /30.
resource "google_compute_route" "google_apis_vip" {
  name             = "${var.vpc_name}-google-apis-vip"
  project          = var.vpc_network_project_id
  network          = google_compute_network.vpc.id
  dest_range       = var.google_apis_vip
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

# Allow internal egress (node<->node Spark, node->PSC endpoints).
resource "google_compute_firewall" "allow_egress_internal" {
  name               = "${var.vpc_name}-allow-egress-internal"
  project            = var.vpc_network_project_id
  network            = google_compute_network.vpc.id
  direction          = "EGRESS"
  destination_ranges = [var.node_subnet_cidr, var.pe_subnet_cidr]
  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }
  priority = 1000
}

# Allow egress to Google APIs over the restricted VIP only (443).
resource "google_compute_firewall" "allow_egress_google_apis" {
  name               = "${var.vpc_name}-allow-egress-google-apis"
  project            = var.vpc_network_project_id
  network            = google_compute_network.vpc.id
  direction          = "EGRESS"
  destination_ranges = [var.google_apis_vip]
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  priority = 1000
}

# Default-deny everything else outbound (lowest precedence).
resource "google_compute_firewall" "deny_egress_all" {
  name               = "${var.vpc_name}-deny-egress-all"
  project            = var.vpc_network_project_id
  network            = google_compute_network.vpc.id
  direction          = "EGRESS"
  destination_ranges = ["0.0.0.0/0"]
  deny { protocol = "all" }
  priority = 65534
}

# ---- Firewall ----
resource "google_compute_firewall" "allow_internal" {
  name      = "${var.vpc_name}-allow-internal"
  project   = var.vpc_network_project_id
  network   = google_compute_network.vpc.id
  direction = "INGRESS"
  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }
  source_ranges = [var.node_subnet_cidr, var.pe_subnet_cidr]
}

resource "google_compute_firewall" "node_to_psc" {
  name      = "${var.vpc_name}-node-to-psc"
  project   = var.vpc_network_project_id
  network   = google_compute_network.vpc.id
  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["443", "6666", "8443-8451"]
  }
  source_ranges      = [var.node_subnet_cidr]
  destination_ranges = [var.pe_subnet_cidr]
}

# NOTE: control-plane/relay traffic is NOT an egress concern here — it flows over the PSC
# endpoints (endpoint subnet), which the internal egress rule above already permits. The
# published Databricks IP ranges would only matter for a non-PSC (public-connectivity)
# design. If a future workload needs a Google API not on the restricted VIP, switch
# google_apis_vip to private.googleapis.com (199.36.153.8/30) and update the DNS zone.
