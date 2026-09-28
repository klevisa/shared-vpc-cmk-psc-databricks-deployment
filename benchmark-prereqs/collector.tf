# -----------------------------------------------------------------------------
# Keyless cost collector SA + its BigQuery reads (prerequisites.md §3).
# Attached to the collector job cluster (benchmark DAB, collector_sa var); reads the
# scoped authorized billing view via ADC. No SA keys, no secret scopes.
# -----------------------------------------------------------------------------

resource "google_service_account" "collector" {
  provider     = google.service_project
  project      = var.gcp_project
  account_id   = var.collector_sa_account_id
  display_name = "Benchmark keyless cost collector"
}

# Read ONLY the scoped authorized view (not the underlying billing export).
resource "google_bigquery_table_iam_member" "collector_view_reader" {
  provider   = google.billing
  project    = var.billing_project
  dataset_id = var.billing_dataset
  table_id   = var.billing_view
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.collector.email}"
}

# jobUser to run the query, time-boxed to the PoC.
resource "google_project_iam_member" "collector_job_user" {
  provider = google.billing
  project  = var.billing_project
  role     = "roles/bigquery.jobUser"
  member   = "serviceAccount:${google_service_account.collector.email}"
  condition {
    title       = "poc-expiry"
    description = "Auto-expire this PoC grant after the PoC end date."
    expression  = "request.time < timestamp(\"${var.poc_expiry}\")"
  }
}

# Feed this to the benchmark DAB's collector_sa variable.
output "collector_sa_email" {
  value = google_service_account.collector.email
}
