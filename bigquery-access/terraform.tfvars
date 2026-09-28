# ============================================================================
# bigquery-access — ILLUSTRATIVE values, replace before applying.
# Keyless BigQuery access for classic clusters via the spark-bigquery-connector.
# ============================================================================
poc_expiry = "2026-12-31T00:00:00Z"

service_project_admin_sa = "svc-project-admin@example-databricks-svc.iam.gserviceaccount.com"
bq_dataset_owner_sa      = "bq-dataset-owner@example-source-data.iam.gserviceaccount.com"

gcp_project                = "example-databricks-svc"
bq_connector_sa_account_id = "databricks-bq-connector"

bq_project = "example-source-data"
bq_dataset = "mail_analytics_poc"
read_write = true
