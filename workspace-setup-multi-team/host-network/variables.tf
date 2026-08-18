# ---- Identity ----
variable "google_service_account_email" {
  type        = string
  description = "NETWORK team's automation SA (impersonated). Standing roles: compute.networkAdmin + compute.securityAdmin + dns.admin on the (existing) HOST project. Runner needs iam.serviceAccountTokenCreator on it."
}

# ---- Projects ----
# NOTE: the host project and the Shared VPC association already exist (Cloud
# Foundation, Phase 0). This config only creates the VPC + subnets within the host.
variable "vpc_network_project_id" {
  type        = string
  description = "EXISTING HOST project id — this config creates the VPC/subnets/firewall/PSC/DNS inside it."
}
variable "google_service_project_number" {
  type        = string
  description = "SERVICE project NUMBER — used for the <num>@cloudservices and service-<num>@compute-system agent emails on the subnet grants."
}
variable "google_region" {
  type    = string
  default = "us-central1"
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
