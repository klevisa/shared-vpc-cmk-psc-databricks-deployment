variable "poc_expiry" {
  type        = string
  description = "RFC3339 UTC timestamp after which the time-boxed grants auto-expire (request.time)."
}

# ---- Impersonated team SAs ----
variable "service_project_admin_sa" {
  type        = string
  description = "SA that administers the project where the BigQuery connector SA is created. No serviceAccount: prefix."
}
variable "bq_dataset_owner_sa" {
  type        = string
  description = "SA that owns the BigQuery data project/dataset and can grant IAM on it. No serviceAccount: prefix."
}

# ---- Where the connector SA lives ----
variable "gcp_project" {
  type        = string
  description = "Project the connector SA is created in (typically the Databricks service project)."
}
variable "bq_connector_sa_account_id" {
  type        = string
  default     = "databricks-bq-connector"
  description = "account_id for the keyless BigQuery connector SA (attached to classic clusters as their Google identity)."
}

# ---- BigQuery target ----
variable "bq_project" {
  type        = string
  description = "Project that holds the BigQuery dataset the connector reads/writes."
}
variable "bq_dataset" {
  type        = string
  description = "BigQuery dataset id the connector is scoped to (dataViewer/dataEditor granted at dataset level)."
}
variable "read_write" {
  type        = bool
  default     = false
  description = "false (default) = read-only (dataViewer only). true = read + write (adds dataEditor). NOTE: dataset-level dataEditor does NOT support an IAM condition, so a write grant does NOT expire at poc_expiry — it is permanent until teardown. Only set true when writes are required, and keep the target dataset in a project separate from any production data."
}
