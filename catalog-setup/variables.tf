# ---- Databricks identities ----
variable "databricks_account_id" { type = string }
variable "account_admin_sa" {
  type        = string
  description = "The Databricks ACCOUNT ADMIN SA (from prereqs). Grants the automation SA the scoped metastore CREATE privileges."
}
variable "catalog_automation_sa" {
  type        = string
  description = "The catalog AUTOMATION SA — manually created + registered as a Databricks user by the account admin as part of this step's setup. Impersonated to create/own the catalogs; holds only the scoped CREATE_* granted below (NOT a metastore admin)."
}

# ---- Handoff from prereqs / Phase 3 ----
variable "metastore_id" {
  type        = string
  description = "The region's Unity Catalog metastore id (the group is granted CREATE on it). Same value as Phase 3's metastore_id."
}
variable "workspace_url" {
  type        = string
  description = "From databricks-account output workspace_url — the workspace UC objects are created against."
}

# ---- GCP team identities ----
variable "perimeter_sa" {
  type        = string
  description = "Cloud/Network Security SA (impersonated). Needs roles/accesscontextmanager.policyAdmin on the perimeter."
}
variable "data_bucket_sa" {
  type        = string
  description = "SA owning the customer's data bucket project (impersonated). Needs bucket IAM admin on the existing data bucket."
}
variable "analytics_bucket_sa" {
  type        = string
  description = "Data Platform SA (impersonated). Needs roles/storage.admin in the analytics bucket's project (creates the bucket + grants IAM)."
}

# ---- VPC-SC (customer-supplied perimeter) ----
variable "perimeter_name" {
  type        = string
  description = "Full service-perimeter name: accessPolicies/<policy>/servicePerimeters/<name>."
}
variable "protected_resources" {
  type        = list(string)
  default     = ["*"]
  description = "ingress_to resources — the perimeter-protected projects the buckets live in, e.g. [\"projects/222222222222\"]. \"*\" allows all in the perimeter."
}
variable "databricks_source_projects" {
  type = list(string)
  # REQUIRED source-pinning: the VPC-SC ingress admits the generated storage-credential SA
  # ONLY when the call originates from these Databricks-owned projects. Include BOTH the
  # Databricks control-plane AND the serverless-compute project numbers for your region, so
  # both paths are covered — the storage-credential SA (classic/UC operations) and serverless
  # compute (which runs in Databricks-owned projects). Look them up in the "IP addresses and
  # domains" table: https://docs.databricks.com/gcp/en/resources/ip-domain-region
  # These are STABLE values Databricks publishes for exactly this purpose — an existing number
  # is never changed out from under a pinned perimeter (that would break every pinned customer).
  # New numbers are only ever ADDED and announced; reconcile the list if that happens, or new
  # traffic from an unlisted project is denied. Format: ["projects/<number>", ...].
  validation {
    condition     = length(var.databricks_source_projects) > 0
    error_message = "Source-pinning is required: set the Databricks control-plane + serverless-compute project numbers for your region (see the ip-domain-region docs)."
  }
  description = "REQUIRED. Databricks control-plane + serverless-compute project numbers that source-pin the VPC-SC ingress. See the ip-domain-region docs."
}

# ---- Read-only catalog (the customer's EXISTING data bucket) ----
variable "readonly_bucket" {
  type        = string
  description = "EXISTING GCS bucket with the customer's data (name only). Accessed read-only."
}
variable "readonly_bucket_project" {
  type        = string
  description = "Project that owns the existing data bucket (google.data_bucket provider project)."
}
variable "readonly_catalog_name" { type = string }
variable "readonly_schema_name" { type = string }
variable "readonly_storage_credential_name" { type = string }
variable "readonly_external_location_name" { type = string }

# ---- Read-write (managed) catalog (the analytics DATA bucket, CREATED here) ----
variable "analytics_bucket" {
  type        = string
  description = "Name of the analytics data bucket to CREATE (globally unique). Backs the read-write managed catalog."
}
variable "analytics_bucket_project" {
  type        = string
  description = "Project to create the analytics data bucket in (google.analytics_bucket provider project)."
}
variable "analytics_bucket_location" {
  type        = string
  description = "Location/region for the analytics data bucket (match the workspace region)."
}
variable "readwrite_catalog_name" { type = string }
variable "readwrite_schema_name" { type = string }
variable "readwrite_storage_credential_name" { type = string }
variable "readwrite_external_location_name" { type = string }
