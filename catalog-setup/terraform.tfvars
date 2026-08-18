# ============================================================================
# Catalog setup — ILLUSTRATIVE values. Runs after the workspace exists.
# ============================================================================

# ---- Databricks identities ----
databricks_account_id      = "00000000-0000-0000-0000-000000000000"
account_admin_sa           = "databricks-automation@example-databricks-svc.iam.gserviceaccount.com" # the account admin (from prereqs)
metastore_admin_sa         = "uc-admin@example-databricks-svc.iam.gserviceaccount.com"              # added to the admin group + creates catalogs
metastore_admin_group_name = "uc-metastore-admins-us-central1"

# ---- from prereqs / Phase 3 ----
metastore_id  = "11111111-2222-3333-4444-555555555555"
workspace_url = "https://1234567890123456.7.gcp.databricks.com"

# ---- GCP team identities (set to the same value if one team owns several) ----
perimeter_sa   = "vpcsc-admin@example-security.iam.gserviceaccount.com"            # Cloud/Network Security
data_bucket_sa = "data-bucket-admin@example-customer-data.iam.gserviceaccount.com" # owner of the source bucket
poc_bucket_sa  = "storage-admin@example-databricks-svc.iam.gserviceaccount.com"    # Data Platform

# ---- VPC-SC (customer-supplied perimeter) ----
perimeter_name      = "accessPolicies/123456789012/servicePerimeters/example_perimeter"
protected_resources = ["*"] # or ["projects/222222222222"] to scope to the buckets' project

# ---- Read-only catalog (the customer's EXISTING data bucket) ----
readonly_bucket                  = "example-customer-data"
readonly_bucket_project          = "example-customer-data"
readonly_catalog_name            = "customer_data_ro"
readonly_schema_name             = "raw"
readonly_storage_credential_name = "cust_data_ro_cred"
readonly_external_location_name  = "cust_data_ro_loc"

# ---- Read-write catalog (the PoC DATA bucket, CREATED here) ----
poc_bucket                        = "example-poc-data"
poc_bucket_project                = "example-databricks-svc"
poc_bucket_location               = "us-central1"
readwrite_catalog_name            = "poc_data"
readwrite_schema_name             = "default"
readwrite_storage_credential_name = "poc_data_cred"
readwrite_external_location_name  = "poc_data_loc"
