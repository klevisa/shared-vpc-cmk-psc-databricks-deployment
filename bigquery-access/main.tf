# -----------------------------------------------------------------------------
# Keyless BigQuery connector SA. Attach it to the classic clusters that run the
# spark-bigquery-connector (gcp_attributes.google_service_account); the connector then
# authenticates via ADC — no key JSON. Grants are dataset-scoped where BigQuery allows and
# poc_expiry-bound where the resource supports IAM conditions.
# -----------------------------------------------------------------------------

resource "google_service_account" "bq" {
  provider     = google.service_project
  project      = var.gcp_project
  account_id   = var.bq_connector_sa_account_id
  display_name = "Databricks BigQuery connector (keyless, cluster-attached)"
}

locals {
  bq_member = "serviceAccount:${google_service_account.bq.email}"
}

# ---- Dataset-level: read (and write if read_write) on the target dataset only ----
resource "google_bigquery_dataset_iam_member" "viewer" {
  provider   = google.bq_dataset
  project    = var.bq_project
  dataset_id = var.bq_dataset
  role       = "roles/bigquery.dataViewer"
  member     = local.bq_member
}

resource "google_bigquery_dataset_iam_member" "editor" {
  count      = var.read_write ? 1 : 0
  provider   = google.bq_dataset
  project    = var.bq_project
  dataset_id = var.bq_dataset
  role       = "roles/bigquery.dataEditor"
  member     = local.bq_member
}

# ---- Project-level: run jobs + Storage Read API sessions, time-boxed ----
resource "google_project_iam_member" "job_user" {
  provider = google.bq_dataset
  project  = var.bq_project
  role     = "roles/bigquery.jobUser"
  member   = local.bq_member
  condition {
    title       = "poc-expiry"
    description = "Auto-expire this PoC grant after the PoC end date."
    expression  = "request.time < timestamp(\"${var.poc_expiry}\")"
  }
}

# The spark-bigquery-connector reads via the BigQuery Storage Read API.
resource "google_project_iam_member" "read_session_user" {
  provider = google.bq_dataset
  project  = var.bq_project
  role     = "roles/bigquery.readSessionUser"
  member   = local.bq_member
  condition {
    title       = "poc-expiry"
    description = "Auto-expire this PoC grant after the PoC end date."
    expression  = "request.time < timestamp(\"${var.poc_expiry}\")"
  }
}

# Feed this to the cluster's gcp_attributes.google_service_account, add it to the cluster
# policy allow-list, and add it to workspace-sa-roles additional_actas_service_accounts.
output "bq_connector_sa_email" {
  value = google_service_account.bq.email
}
