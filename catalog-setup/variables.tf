# ---- Identities ----
variable "databricks_service_account_email" {
  type        = string
  description = "Data Platform SA (impersonated for the workspace/UC provider). Needs Unity Catalog metastore-admin / CREATE privileges. Runner needs iam.serviceAccountTokenCreator on it."
}
variable "gcp_service_account_email" {
  type        = string
  description = "Security SA (impersonated for the google provider). Needs bucket IAM admin on the buckets' project(s) and accesscontextmanager.policyAdmin for the VPC-SC ingress. Runner needs iam.serviceAccountTokenCreator on it."
}
variable "google_project" {
  type        = string
  description = "Project used as the google provider's quota/context project (e.g. the service project)."
}

# ---- Handoff from Phase 3 (databricks-account) ----
variable "workspace_url" {
  type        = string
  description = "From databricks-account output workspace_url — the workspace these UC objects are created against."
}

# ---- VPC-SC (customer-supplied perimeter) ----
variable "perimeter_name" {
  type        = string
  description = "Full service-perimeter name to attach ingress rules to: accessPolicies/<policy>/servicePerimeters/<name>."
}
variable "protected_resources" {
  type        = list(string)
  default     = ["*"]
  description = "ingress_to resources — the perimeter-protected projects the buckets live in, e.g. [\"projects/222222222222\"]. \"*\" allows all projects in the perimeter."
}

# ---- Read-only catalog (their existing data bucket) ----
variable "readonly_bucket" {
  type        = string
  description = "EXISTING GCS bucket holding the customer's data (name only, no gs:// prefix). Accessed read-only."
}
variable "readonly_catalog_name" { type = string }
variable "readonly_schema_name" { type = string }
variable "readonly_storage_credential_name" { type = string }
variable "readonly_external_location_name" { type = string }

# ---- Read-write catalog (scratch / output bucket) ----
variable "readwrite_bucket" {
  type        = string
  description = "EXISTING GCS bucket for PoC output (name only). Managed tables in the read-write catalog land here."
}
variable "readwrite_catalog_name" { type = string }
variable "readwrite_schema_name" { type = string }
variable "readwrite_storage_credential_name" { type = string }
variable "readwrite_external_location_name" { type = string }
