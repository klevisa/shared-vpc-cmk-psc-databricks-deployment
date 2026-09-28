# Keyless BigQuery access for classic clusters (POC1a). The Databricks BigQuery Lakehouse
# Federation *connection* takes a GCP SA key JSON (no keyless option) — against Yahoo's
# no-keys rule. Since this is a classic-cluster POC, the keyless path is the
# spark-bigquery-connector authenticating as the cluster's ATTACHED Google SA via ADC.
# This root creates that SA and grants it least-privilege BigQuery access.
#
# Two aliased providers, each impersonating the owning team's SA (runner needs
# serviceAccountTokenCreator on both):
#   service_project : owns the project where the SA lives — creates the SA.
#   bq_dataset      : owns the BigQuery data project/dataset — grants the SA on it.

provider "google" {
  alias                       = "service_project"
  project                     = var.gcp_project
  impersonate_service_account = var.service_project_admin_sa
}

provider "google" {
  alias                       = "bq_dataset"
  project                     = var.bq_project
  impersonate_service_account = var.bq_dataset_owner_sa
}
