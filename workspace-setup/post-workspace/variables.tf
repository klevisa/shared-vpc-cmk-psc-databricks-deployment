# ---- Identity ----
variable "google_service_account_email" {
  type        = string
  description = "NETWORK team's automation SA (same as step 2.2). Needs compute.networkAdmin + dns.admin + roles/iam.roleAdmin (for the custom network role) on the HOST project. Runner needs iam.serviceAccountTokenCreator on it."
}

# ---- Handoff from step 2.2 (network) ----
variable "vpc_network_project_id" {
  type        = string
  description = "From network output host_project."
}
variable "google_region" { type = string }

# ---- PoC time-box ----
# RFC3339 UTC timestamp after which the workspace-SA network grant auto-expires, via a
# request.time IAM condition. Set it to the PoC end date. Backstops teardown; does not
# replace it. (Not applied to the read-only creator roles/SA — those are stripped outright
# right after finalize; see workspace-setup/creator-teardown/.)
variable "poc_expiry" {
  type        = string
  description = "RFC3339 UTC timestamp after which this config's PoC IAM grants auto-expire (request.time IAM condition), e.g. \"2026-12-31T00:00:00Z\"."
}

variable "node_subnet_name" {
  type        = string
  description = "From network output node_subnet_name."
}
variable "private_zone_name" {
  type        = string
  description = "From network output private_zone_name."
}
variable "dns_name" {
  type        = string
  description = "From network output dns_name (trailing dot)."
}
variable "frontend_pe_ip" {
  type        = string
  description = "From network output frontend_pe_ip."
}
variable "backend_pe_ip" {
  type        = string
  description = "From network output backend_pe_ip."
}

# ---- Handoff from step 2.4 (workspace) ----
variable "gcp_workspace_sa" {
  type        = string
  description = "From workspace output gcp_workspace_sa (db-<id>@prod-gcp-<region>, no serviceAccount: prefix)."
}
variable "workspace_url" {
  type        = string
  description = "From workspace output workspace_url (https://<num>.<n>.gcp.databricks.com)."
}
