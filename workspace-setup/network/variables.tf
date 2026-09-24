# ---- Identity ----
variable "google_service_account_email" {
  type        = string
  description = "NETWORK team's automation SA (impersonated). Standing roles: compute.networkAdmin + compute.securityAdmin + dns.admin + roles/iam.roleAdmin on the (existing) HOST project. Where the host carries other tenants, CONDITION networkAdmin/securityAdmin on resource.name of this VPC and its subnets so a PoC runner can't edit other tenants' firewall/subnet IAM. Runner needs iam.serviceAccountTokenCreator on it."
}

# The least-privilege workspace CREATOR SA (db account-admin automation SA, impersonated by
# step 2.4). Granted the read-only creator role on the HOST project here.
variable "databricks_account_admin_sa" {
  type        = string
  description = "Workspace creator SA email, granted the read-only creator role on the host project. No serviceAccount: prefix."
}

# End-state teardown toggle. TRUE during workspace creation (steps 2.1-2.4). After the
# workspace is RUNNING (2.8), flip to FALSE and re-apply to strip the read-only creator role
# on the host project — it is only needed at creation. See workspace-setup/creator-teardown/.
variable "create_workspace_creator_role" {
  type        = bool
  default     = true
  description = "Whether to grant the read-only workspace-creator role on the host project. Set false in the End state (after step 2.8) to tear it down."
}

# Backstop expiry on the (read-only) creator-role grant — it's removed outright at 2.9, this
# just makes a stale binding fail closed. RFC3339 UTC, e.g. "2026-12-31T00:00:00Z".
variable "poc_expiry" {
  type        = string
  description = "RFC3339 UTC timestamp after which the creator-role grant auto-expires (request.time backstop)."
}

# ---- Projects ----
# NOTE: the host project and the Shared VPC association already exist (Cloud
# Foundation, step 2.1). This config only creates the VPC + subnets within the host.
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

# ---- DNS (zone only; records are step 2.6) ----
variable "private_zone_name" {
  type    = string
  default = "databricks"
}
variable "dns_name" {
  type    = string
  default = "gcp.databricks.com." # trailing dot required
}
