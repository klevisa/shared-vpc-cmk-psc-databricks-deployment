# -----------------------------------------------------------------------------
# HOST-project network (Shared VPC). Owned by Network Engineering.
# In a real Shared VPC the network team often PRE-CREATES the VPC/subnets and you
# reference them with data sources; here they're created for a self-contained
# illustration. Records for the DNS zone are added in Phase 4 (post-workspace).
# -----------------------------------------------------------------------------

# ---- Shared VPC association (skip if Cloud Foundation already did it) ----
resource "google_compute_shared_vpc_host_project" "host" {
  count   = var.manage_shared_vpc_association ? 1 : 0
  project = var.vpc_network_project_id
}

resource "google_compute_shared_vpc_service_project" "service" {
  count           = var.manage_shared_vpc_association ? 1 : 0
  host_project    = var.vpc_network_project_id
  service_project = var.google_project_name
  depends_on      = [google_compute_shared_vpc_host_project.host]
}

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

# ---- Egress for no-external-IP nodes ----
resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-router"
  project = var.vpc_network_project_id
  region  = var.google_region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.vpc_name}-nat"
  project                            = var.vpc_network_project_id
  router                             = google_compute_router.router.name
  region                             = var.google_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
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
