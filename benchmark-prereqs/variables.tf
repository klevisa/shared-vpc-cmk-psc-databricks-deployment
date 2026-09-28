# ---- PoC lifetime ----
variable "poc_expiry" {
  type        = string
  description = "RFC3339 UTC timestamp after which the time-boxed grants auto-expire (request.time). e.g. 2026-12-31T00:00:00Z."
}

# ---- Impersonated team SAs (one per provider; see providers.tf) ----
variable "service_project_admin_sa" {
  type        = string
  description = "SA that administers the service/Dataproc project (creates the collector SA + custom Dataproc role, grants Composer). No serviceAccount: prefix."
}
variable "source_bucket_sa" {
  type        = string
  description = "SA that owns the existing source (Mail) bucket — grants read on it. No serviceAccount: prefix."
}
variable "poc_bucket_sa" {
  type        = string
  description = "SA that owns the copy-target project — creates poc_bucket + grants write. No serviceAccount: prefix."
}
variable "billing_sa" {
  type        = string
  description = "SA that owns the billing project + authorized view — grants the collector BQ read. No serviceAccount: prefix."
}
variable "perimeter_sa" {
  type        = string
  description = "Cloud/Network Security SA for the VPC-SC ingress rule. Grant policyAdmin on a SCOPED access policy (a PoC folder), not the org default. No serviceAccount: prefix."
}

# ---- Projects ----
variable "gcp_project" {
  type        = string
  description = "Service/Dataproc project — where the collector SA and custom Dataproc role live."
}
variable "source_bucket" {
  type        = string
  description = "Name of the EXISTING source (Mail) bucket the benchmark copies input from (read-only)."
}
variable "source_bucket_project" {
  type        = string
  description = "Project that owns the existing source (Mail) bucket."
}
variable "poc_bucket_project" {
  type        = string
  description = "Project for the copy-target poc_bucket (and the STS transfer)."
}
variable "billing_project" {
  type        = string
  description = "Project that holds the BigQuery billing export + the scoped authorized view."
}

# ---- Collector SA + BigQuery ----
variable "collector_sa_account_id" {
  type        = string
  default     = "gcp-data-collector"
  description = "account_id for the keyless collector SA created in gcp_project (attached to the collector job cluster; reads the billing view via ADC)."
}
variable "billing_dataset" {
  type        = string
  description = "BigQuery dataset holding the scoped authorized view (e.g. benchmark_billing)."
}
variable "billing_view" {
  type        = string
  description = "The scoped authorized view the collector may read (e.g. vm_cost_by_run)."
}

# ---- Airflow (Composer) ----
variable "composer_sa" {
  type        = string
  description = "Cloud Composer environment SA (created by Composer, not here) — granted the Dataproc role, GCS read/write, and STS. No serviceAccount: prefix."
}

# ---- Source read scoping ----
variable "source_object_prefix" {
  type        = string
  default     = "mail-data/"
  description = "Object-name prefix on the source bucket that the copy reads. SAMPLE — set to the real input prefix during the PoC. Empty = whole bucket."
}
variable "source_cmek_key" {
  type        = string
  default     = ""
  description = "OPTIONAL. If the source bucket uses a customer-managed key, its full KMS id, so the STS agent can be granted decrypt. Empty = source uses Google-managed encryption (no grant)."
}

# ---- Copy target ----
variable "poc_bucket_name" {
  type        = string
  description = "Name of the copy-target bucket created here (deleted at teardown)."
}
variable "poc_bucket_location" {
  type        = string
  default     = "us-central1"
  description = "Location for poc_bucket."
}

# ---- VPC-SC ----
variable "perimeter_name" {
  type        = string
  description = "Full service-perimeter name: accessPolicies/<policy>/servicePerimeters/<name>."
}
variable "sts_protected_resources" {
  type        = list(string)
  description = "Projects the STS ingress rule admits (the source and poc_bucket projects, as projects/<number>). Do NOT use [\"*\"]."
  validation {
    condition     = length(var.sts_protected_resources) > 0 && !contains(var.sts_protected_resources, "*")
    error_message = "Pin sts_protected_resources to the source + poc_bucket projects; \"*\" is not allowed."
  }
}

# ---- Databricks (UC grants + run-as SPs) ----
variable "workspace_url" {
  type        = string
  description = "Workspace URL for the uc_admin provider (applies the SP Unity Catalog grants)."
}
variable "uc_grantor_sp" {
  type        = string
  description = "Metastore-admin SP application id (OAuth client_id) that applies the UC grants. Must be able to grant on analytics, source_data_ro and system."
}
variable "uc_grantor_client_secret" {
  type        = string
  sensitive   = true
  description = "OAuth M2M secret for uc_grantor_sp. Source from a secret manager / TF_VAR env var; do not hard-code."
}
variable "runner_sp" {
  type        = string
  description = "bench-runner SP application id (UC grant principal)."
}
variable "collector_sp" {
  type        = string
  description = "bench-collector SP application id (UC grant principal)."
}
variable "analyst_sp" {
  type        = string
  description = "bench-analyst SP application id (UC grant principal)."
}
