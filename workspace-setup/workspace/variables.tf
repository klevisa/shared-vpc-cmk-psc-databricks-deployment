# ---- Identity ----
variable "databricks_account_admin_sa" {
  type        = string
  description = "The Databricks account-admin automation SA: a GCP service account registered as a Databricks account-admin USER, impersonated for account-API auth to create the workspace. Distinct from the human account admin who subscribed via the Marketplace. Runner needs iam.serviceAccountTokenCreator on it. See databricks-account-setup/README.md (1.1)."
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
  description = "REQUIRED: the region's Unity Catalog metastore id. The workspace is explicitly assigned to it. See databricks-account-setup/README.md."
}

# ---- Handoff from step 2.3 (cmek) ----
variable "cmek_key_id" {
  type        = string
  description = "From cmek output cmek_key_id: full KMS resource id."
}

# ---- Handoff from step 2.2 (network) ----
variable "vpc_network_project_id" {
  type        = string
  description = "From network output host_project."
}
variable "vpc_name" {
  type        = string
  description = "From network output vpc_name."
}
variable "node_subnet_name" {
  type        = string
  description = "From network output node_subnet_name."
}
variable "workspace_pe" {
  type        = string
  description = "From network output workspace_pe (frontend PSC endpoint name)."
}
variable "relay_pe" {
  type        = string
  description = "From network output relay_pe (backend PSC endpoint name)."
}
