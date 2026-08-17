# ---- Identity ----
variable "google_service_account_email" {
  type        = string
  description = "NETWORK team's automation SA (impersonated). Standing roles: compute.networkAdmin + compute.securityAdmin + dns.admin on the HOST project. If manage_shared_vpc_association = true, also compute.xpnAdmin at the org/folder. Runner needs iam.serviceAccountTokenCreator on it."
}

# ---- Projects ----
variable "vpc_network_project_id" {
  type        = string
  description = "HOST project id (owns the Shared VPC, subnets, firewall, PSC, DNS)."
}
variable "google_project_name" {
  type        = string
  description = "SERVICE project id — attached to the Shared VPC and referenced when building the service-agent emails for the subnet grants."
}
variable "google_service_project_number" {
  type        = string
  description = "SERVICE project NUMBER — used for the <num>@cloudservices and service-<num>@compute-system agent emails."
}
variable "google_region" {
  type    = string
  default = "us-central1"
}

# ---- Shared VPC association ----
variable "manage_shared_vpc_association" {
  type        = bool
  default     = true
  description = "true = this config enables the host + attaches the service project (needs xpnAdmin). false = Cloud Foundation already did it (Phase 0)."
}

# ---- Network ----
variable "vpc_name" { type = string }
variable "node_subnet_name" { type = string }
variable "node_subnet_cidr" { type = string }
variable "pe_subnet_name" { type = string }
variable "pe_subnet_cidr" { type = string }

# ---- PSC endpoints ----
variable "workspace_pe" { type = string }
variable "relay_pe" { type = string }
variable "workspace_pe_ip_name" { type = string }
variable "relay_pe_ip_name" { type = string }
variable "workspace_service_attachment" { type = string }
variable "relay_service_attachment" { type = string }

# ---- DNS (zone only; records are Phase 4) ----
variable "private_zone_name" {
  type    = string
  default = "databricks"
}
variable "dns_name" {
  type    = string
  default = "gcp.databricks.com." # trailing dot required
}
