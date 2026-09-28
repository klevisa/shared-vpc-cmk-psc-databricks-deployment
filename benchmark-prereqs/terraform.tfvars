# ============================================================================
# benchmark-prereqs — ILLUSTRATIVE values, replace before applying.
# Codifies the grants that used to be manual gcloud/console steps (prerequisites.md §3-5).
# ============================================================================
poc_expiry = "2026-12-31T00:00:00Z"

# Impersonated team SAs (each provider; see providers.tf)
service_project_admin_sa = "svc-project-admin@example-databricks-svc.iam.gserviceaccount.com"
source_bucket_sa         = "source-bucket-owner@example-source-data.iam.gserviceaccount.com"
poc_bucket_sa            = "poc-bucket-owner@example-databricks-svc.iam.gserviceaccount.com"
billing_sa               = "billing-view-owner@billing-project.iam.gserviceaccount.com"
perimeter_sa             = "netsec-perimeter@example-netsec.iam.gserviceaccount.com"

# Projects
gcp_project           = "example-databricks-svc"
source_bucket_project = "example-source-data"
poc_bucket_project    = "example-databricks-svc"
billing_project       = "billing-project"

# Collector SA + BigQuery view
collector_sa_account_id = "gcp-data-collector"
billing_dataset         = "benchmark_billing"
billing_view            = "vm_cost_by_run"

# Airflow (Composer) — SA created by the Composer environment, granted here
composer_sa = "composer-env@example-databricks-svc.iam.gserviceaccount.com"

# Source read scoping — SAMPLE prefix; set to the real input path during the PoC
source_bucket        = "example-source-data"
source_object_prefix = "mail-data/"
source_cmek_key      = "" # set only if the source bucket uses a customer-managed key

# Copy target (deleted at teardown)
poc_bucket_name     = "example-benchmark-poc-input"
poc_bucket_location = "us-central1"

# VPC-SC — pin to the source + poc_bucket projects (project numbers), never "*"
perimeter_name          = "accessPolicies/123456789/servicePerimeters/yahoo_mail_poc"
sts_protected_resources = ["projects/111111111111", "projects/222222222222"]

# Databricks — UC grants applied as a metastore-admin SP (OAuth M2M)
workspace_url = "https://1234567890123456.7.gcp.databricks.com"
uc_grantor_sp = "00000000-0000-0000-0000-0000000000aa" # metastore-admin SP application id
# Source the secret from env: export TF_VAR_uc_grantor_client_secret=...
uc_grantor_client_secret = "REPLACE_VIA_TF_VAR_ENV"
runner_sp                = "00000000-0000-0000-0000-00000000aaaa"
collector_sp             = "00000000-0000-0000-0000-00000000bbbb"
analyst_sp               = "00000000-0000-0000-0000-00000000cccc"
