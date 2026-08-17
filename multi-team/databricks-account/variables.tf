# ---- Identity ----
variable "google_service_account_email" {
  type        = string
  description = "DATA PLATFORM team's automation SA (impersonated for account-API auth). Must be a Databricks ACCOUNT ADMIN. Runner needs iam.serviceAccountTokenCreator on it."
}

# ---- Databricks account / workspace ----
variable "databricks_account_id" { type = string }
variable "databricks_workspace_name" { type = string }
variable "google_project_name" {
  type        = string
  description = "SERVICE project id — the workspace's GCE/GCS resources land here (cloud_resource_container)."
}
variable "google_region" { type = string }
variable "public_access_enabled" {
  type        = bool
  default     = false
  description = "IMMUTABLE after creation. false = fully private (PSC-only)."
}
variable "metastore_id" {
  type        = string
  default     = ""
  description = "Optional existing UC metastore to assign. Empty = auto-assignment."
}

# ---- Handoff from Phase 2 (service-cmek) ----
variable "cmek_key_id" {
  type        = string
  description = "From service-cmek output cmek_key_id: full KMS resource id."
}

# ---- Handoff from Phase 1 (host-network) ----
variable "vpc_network_project_id" {
  type        = string
  description = "From host-network output host_project."
}
variable "vpc_name" {
  type        = string
  description = "From host-network output vpc_name."
}
variable "node_subnet_name" {
  type        = string
  description = "From host-network output node_subnet_name."
}
variable "workspace_pe" {
  type        = string
  description = "From host-network output workspace_pe (frontend PSC endpoint name)."
}
variable "relay_pe" {
  type        = string
  description = "From host-network output relay_pe (backend PSC endpoint name)."
}
