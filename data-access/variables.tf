# ---- PoC time-box ----
# RFC3339 UTC timestamp after which the bucket-IAM grants (read-only on your existing data
# bucket, read-write on the analytics bucket) auto-expire, via a request.time IAM
# condition. Set it to the PoC end date. Backstops teardown; does not replace it. NOTE:
# GCS IAM conditions require UNIFORM BUCKET-LEVEL ACCESS on the target bucket (the
# analytics bucket sets it; confirm your existing data bucket has it too).
variable "poc_expiry" {
  type        = string
  description = "RFC3339 UTC timestamp after which this config's bucket-IAM grants auto-expire (request.time IAM condition), e.g. \"2026-12-31T00:00:00Z\"."
}

# ---- Databricks identities ----
variable "databricks_account_id" { type = string }
variable "account_admin_sp" {
  type        = string
  description = "Account-admin service principal application id (OAuth M2M client_id). Grants the catalog automation SP the scoped metastore CREATE privileges."
}
variable "account_admin_sp_client_secret" {
  type        = string
  sensitive   = true
  description = "OAuth M2M client secret for account_admin_sp. Source via TF_VAR_account_admin_sp_client_secret; do not hard-code."
}
variable "catalog_automation_sp" {
  type        = string
  description = "The catalog AUTOMATION service principal — a native Databricks SP created by the account admin for this step. This is its application id (also the OAuth client_id and the grant principal). It creates/owns the catalogs and holds only the scoped CREATE_* granted below (NOT a metastore admin)."
}
variable "catalog_automation_client_secret" {
  type        = string
  sensitive   = true
  description = "OAuth M2M client secret for catalog_automation_sp. Source it from a secret manager / TF_VAR env var — do not hard-code."
}

# ---- Handoff from prereqs / step 2.4 ----
variable "metastore_id" {
  type        = string
  description = "The region's Unity Catalog metastore id (the group is granted CREATE on it). Same value as step 2.4's metastore_id."
}
variable "workspace_url" {
  type        = string
  description = "From workspace output workspace_url — the workspace UC objects are created against."
}
variable "workspace_id" {
  type        = string
  description = "From workspace output workspace_id — the workspace the catalogs/credentials/locations are bound to (isolation)."
}

# ---- Ownership + isolation ----
variable "governance_group" {
  type        = string
  description = "IdP-synced governance group set as OWNER of the catalogs, credentials, and external locations (ownership transfers off the automation SP; a metastore admin can reassign later)."
}

# ---- GCP team identities ----
variable "perimeter_sa" {
  type        = string
  description = "Cloud/Network Security SA (impersonated). Needs accesscontextmanager.policyAdmin — but grant it on a SCOPED access policy (a PoC folder-scoped policy, gcloud access-context-manager policies create --scopes=folders/...), not the org default policy, so it can't edit every perimeter in the org. If the org uses one shared perimeter, move these two ingress rules into Network Security's own perimeter config and have this phase only output the generated SA emails."
}
variable "data_bucket_sa" {
  type        = string
  description = "SA owning your data bucket project (impersonated). Grant it a BUCKET-SCOPED role on the source bucket only — roles/storage.admin on the bucket resource, or roles/storage.legacyBucketOwner (bucket-level setIamPolicy, no object write) — NOT project-wide admin on the sensitive source project."
}
variable "analytics_bucket_sa" {
  type        = string
  description = "Data Platform SA (impersonated). Creates the analytics bucket + grants IAM. Put the analytics bucket in a SEPARATE data project (not the workspace service project) so this SA's storage.admin can't reach the workspace's own buckets; if it must live in the service project, condition storage.admin to the analytics bucket resource."
}

# ---- VPC-SC (your existing perimeter) ----
variable "perimeter_name" {
  type        = string
  description = "Full service-perimeter name: accessPolicies/<policy>/servicePerimeters/<name>."
}
# ingress_to resources, split per catalog (the buckets live in different projects). NO "*"
# default — that would admit the storage-credential SA to every project in the perimeter.
variable "readonly_protected_resources" {
  type        = list(string)
  description = "ingress_to for the RO rule — the source-data bucket's project only, e.g. [\"projects/222222222222\"]."
  validation {
    condition     = length(var.readonly_protected_resources) > 0 && !contains(var.readonly_protected_resources, "*")
    error_message = "Set the source-data project explicitly (e.g. [\"projects/<num>\"]); \"*\" is not allowed."
  }
}
variable "readwrite_protected_resources" {
  type        = list(string)
  description = "ingress_to for the RW rule — the analytics bucket's project only, e.g. [\"projects/333333333333\"]."
  validation {
    condition     = length(var.readwrite_protected_resources) > 0 && !contains(var.readwrite_protected_resources, "*")
    error_message = "Set the analytics project explicitly (e.g. [\"projects/<num>\"]); \"*\" is not allowed."
  }
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
  # is never changed out from under a pinned perimeter (that would break every pinned perimeter).
  # New numbers are only ever ADDED and announced; reconcile the list if that happens, or new
  # traffic from an unlisted project is denied. Format: ["projects/<number>", ...].
  validation {
    condition     = length(var.databricks_source_projects) > 0
    error_message = "Source-pinning is required: set the Databricks control-plane + serverless-compute project numbers for your region (see the ip-domain-region docs)."
  }
  description = "REQUIRED. Databricks control-plane + serverless-compute project numbers that source-pin the VPC-SC ingress. See the ip-domain-region docs."
}

# ---- Read-only catalog (your EXISTING data bucket) ----
variable "readonly_bucket" {
  type        = string
  description = "EXISTING GCS bucket with your data (name only). Accessed read-only."
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
