# ============================================================================
# Catalog setup — ILLUSTRATIVE values. Runs after the workspace exists.
# ============================================================================

# PoC end date — the read-only + read-write bucket IAM grants auto-expire after this
# (request.time). Requires uniform bucket-level access on each target bucket.
poc_expiry = "2026-12-31T00:00:00Z"

# ---- Databricks identities ----
databricks_account_id = "00000000-0000-0000-0000-000000000000"
account_admin_sp      = "00000000-0000-0000-0000-0000000000aa" # account-admin SP application id (OAuth client_id)
catalog_automation_sp = "00000000-0000-0000-0000-0000000000dd" # automation SP application id (OAuth client_id); creates/owns the catalogs
# Source both OAuth secrets from env (don't hard-code):
#   export TF_VAR_account_admin_sp_client_secret=...   export TF_VAR_catalog_automation_client_secret=...
account_admin_sp_client_secret   = "REPLACE_VIA_TF_VAR_ENV"
catalog_automation_client_secret = "REPLACE_VIA_TF_VAR_ENV"

# Keep true for the first apply (SP builds the locations/credentials). After they exist, set
# false and re-apply to revoke CREATE_EXTERNAL_LOCATION + CREATE_STORAGE_CREDENTIAL.
grant_credential_location_create = true

# ---- from prereqs / step 2.4 ----
metastore_id  = "11111111-2222-3333-4444-555555555555"
workspace_url = "https://1234567890123456.7.gcp.databricks.com"
workspace_id  = "1234567890123456" # for the workspace bindings (isolation)

# IdP-synced governance group set as OWNER of the catalogs/credentials/locations.
governance_group = "data-governance-admins"

# ---- GCP team identities (set to the same value if one team owns several) ----
perimeter_sa        = "vpcsc-admin@example-security.iam.gserviceaccount.com"          # Cloud/Network Security
data_bucket_sa      = "data-bucket-admin@example-source-data.iam.gserviceaccount.com" # owner of the source bucket
analytics_bucket_sa = "storage-admin@example-databricks-svc.iam.gserviceaccount.com"  # Data Platform

# ---- VPC-SC (your existing perimeter) ----
perimeter_name = "accessPolicies/123456789012/servicePerimeters/example_perimeter"
# ingress_to scoped per catalog to the buckets' own projects — no "*".
readonly_protected_resources  = ["projects/222222222222"] # source-data bucket's project
readwrite_protected_resources = ["projects/333333333333"] # analytics bucket's project

# Source-pin the ingress to Databricks' own projects. REQUIRED — include BOTH the
# control-plane and the serverless-compute project numbers for your region (covers the
# storage-credential SA and serverless compute). Look up your region's values at
# https://docs.databricks.com/gcp/en/resources/ip-domain-region  (replace the examples).
databricks_source_projects = [
  "projects/000000000001", # Databricks control-plane project (your region)
  "projects/000000000002", # Databricks serverless-compute project (your region)
]

# ---- Read-only catalog (your EXISTING data bucket) ----
readonly_bucket                  = "example-source-data"
readonly_bucket_project          = "example-source-data"
readonly_catalog_name            = "source_data_ro"
readonly_schema_name             = "raw"
readonly_storage_credential_name = "cust_data_ro_cred"
readonly_external_location_name  = "cust_data_ro_loc"

# ---- Read-write (managed) catalog (the analytics DATA bucket, CREATED here) ----
analytics_bucket                  = "example-analytics-data"
analytics_bucket_project          = "example-analytics-data-proj" # SEPARATE data project, not the workspace service project (H3)
analytics_bucket_location         = "us-central1"
readwrite_catalog_name            = "analytics"
readwrite_schema_name             = "default"
readwrite_storage_credential_name = "analytics_cred"
readwrite_external_location_name  = "analytics_loc"
