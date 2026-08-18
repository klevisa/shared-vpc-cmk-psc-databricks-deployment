# ============================================================================
# Catalog setup — ILLUSTRATIVE values. Runs after the workspace exists.
# ============================================================================

# ---- Identities ----
databricks_service_account_email = "databricks-automation@example-databricks-svc.iam.gserviceaccount.com" # Data Platform SA (UC admin)
gcp_service_account_email        = "catalog-security@example-databricks-svc.iam.gserviceaccount.com"       # Security SA (bucket IAM + VPC-SC)
google_project                   = "example-databricks-svc"

# ---- from Phase 3 (databricks-account) ----
workspace_url = "https://1234567890123456.7.gcp.databricks.com"

# ---- VPC-SC (customer-supplied perimeter) ----
perimeter_name      = "accessPolicies/123456789012/servicePerimeters/example_perimeter"
protected_resources = ["*"] # or ["projects/222222222222"] to scope to the buckets' project

# ---- Read-only catalog (their existing data bucket) ----
readonly_bucket                  = "example-customer-data"
readonly_catalog_name            = "customer_data_ro"
readonly_schema_name             = "raw"
readonly_storage_credential_name = "cust_data_ro_cred"
readonly_external_location_name  = "cust_data_ro_loc"

# ---- Read-write catalog (PoC scratch / output bucket) ----
readwrite_bucket                  = "example-poc-scratch"
readwrite_catalog_name            = "poc_scratch"
readwrite_schema_name             = "default"
readwrite_storage_credential_name = "poc_scratch_cred"
readwrite_external_location_name  = "poc_scratch_loc"
