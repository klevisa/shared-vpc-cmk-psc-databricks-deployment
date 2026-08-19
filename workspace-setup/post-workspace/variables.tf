# ---- Identity ----
variable "google_service_account_email" {
  type        = string
  description = "NETWORK team's automation SA (same as step 2.2). Needs compute.networkAdmin + dns.admin on the HOST project. Runner needs iam.serviceAccountTokenCreator on it."
}

# ---- Handoff from step 2.2 (network) ----
variable "vpc_network_project_id" {
  type        = string
  description = "From network output host_project."
}
variable "google_region" { type = string }
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
