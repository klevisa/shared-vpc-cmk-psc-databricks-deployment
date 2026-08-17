# ---- Identity ----
variable "google_service_account_email" {
  type        = string
  description = "NETWORK team's automation SA (same as Phase 1). Needs compute.networkAdmin + dns.admin on the HOST project. Runner needs iam.serviceAccountTokenCreator on it."
}

# ---- Handoff from Phase 1 (host-network) ----
variable "vpc_network_project_id" {
  type        = string
  description = "From host-network output host_project."
}
variable "google_region" { type = string }
variable "node_subnet_name" {
  type        = string
  description = "From host-network output node_subnet_name."
}
variable "private_zone_name" {
  type        = string
  description = "From host-network output private_zone_name."
}
variable "dns_name" {
  type        = string
  description = "From host-network output dns_name (trailing dot)."
}
variable "frontend_pe_ip" {
  type        = string
  description = "From host-network output frontend_pe_ip."
}
variable "backend_pe_ip" {
  type        = string
  description = "From host-network output backend_pe_ip."
}

# ---- Handoff from Phase 3 (databricks-account) ----
variable "gcp_workspace_sa" {
  type        = string
  description = "From databricks-account output gcp_workspace_sa (db-<id>@prod-gcp-<region>, no serviceAccount: prefix)."
}
variable "workspace_url" {
  type        = string
  description = "From databricks-account output workspace_url (https://<num>.<n>.gcp.databricks.com)."
}

# ---- Optional extra network users ----
variable "additional_network_user_service_accounts" {
  type        = list(string)
  default     = []
  description = "Extra SA emails (no prefix) that need compute.networkUser on the shared subnet (e.g. GKE robot, serverless VPC-access agent)."
}
