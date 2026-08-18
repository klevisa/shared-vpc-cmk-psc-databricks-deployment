# ============================================================================
# Catalog setup — ILLUSTRATIVE values. Runs after the workspace exists.
# ============================================================================

# ---- Databricks identities ----
databricks_account_id = "00000000-0000-0000-0000-000000000000"
account_admin_sa      = "databricks-automation@example-databricks-svc.iam.gserviceaccount.com" # the account admin (from prereqs)
catalog_automation_sa = "catalog-automation@example-databricks-svc.iam.gserviceaccount.com"    # manual, account-admin-created; creates/owns the catalogs

# ---- from prereqs / Phase 3 ----
metastore_id  = "11111111-2222-3333-4444-555555555555"
workspace_url = "https://1234567890123456.7.gcp.databricks.com"

# ---- GCP team identities (set to the same value if one team owns several) ----
perimeter_sa        = "vpcsc-admin@example-security.iam.gserviceaccount.com"            # Cloud/Network Security
data_bucket_sa      = "data-bucket-admin@example-customer-data.iam.gserviceaccount.com" # owner of the source bucket
analytics_bucket_sa = "storage-admin@example-databricks-svc.iam.gserviceaccount.com"    # Data Platform

# ---- VPC-SC (customer-supplied perimeter) ----
perimeter_name      = "accessPolicies/123456789012/servicePerimeters/example_perimeter"
protected_resources = ["*"] # or ["projects/222222222222"] to scope to the buckets' project

# Source-pin the ingress to Databricks' own projects (control-plane + serverless-compute).
# Stable, per-region project numbers — look up your region's values in the table at
# https://docs.databricks.com/gcp/en/resources/ip-domain-region  (leave [] for identity-only).
databricks_source_projects = [
  # "projects/000000000001", # Databricks control-plane project (your region)
  # "projects/000000000002", # Databricks serverless-compute project (your region)
]

# ---- Read-only catalog (the customer's EXISTING data bucket) ----
readonly_bucket                  = "example-customer-data"
readonly_bucket_project          = "example-customer-data"
readonly_catalog_name            = "customer_data_ro"
readonly_schema_name             = "raw"
readonly_storage_credential_name = "cust_data_ro_cred"
readonly_external_location_name  = "cust_data_ro_loc"

# ---- Read-write (managed) catalog (the analytics DATA bucket, CREATED here) ----
analytics_bucket                  = "example-analytics-data"
analytics_bucket_project          = "example-databricks-svc"
analytics_bucket_location         = "us-central1"
readwrite_catalog_name            = "analytics"
readwrite_schema_name             = "default"
readwrite_storage_credential_name = "analytics_cred"
readwrite_external_location_name  = "analytics_loc"
