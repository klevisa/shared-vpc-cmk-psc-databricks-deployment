# ============================================================================
# step 2.3 — Cloud Security / KMS. ILLUSTRATIVE values — replace before applying.
# Runs in parallel with step 2.2.
# ============================================================================
google_service_account_email  = "kms-automation@example-databricks-svc.iam.gserviceaccount.com"
google_project_name           = "example-databricks-svc" # from step 2.1 output service_project_id
google_service_project_number = "111111111111"           # from step 2.1 output service_project_number
google_region                 = "us-central1"

kms_keyring_name = "example-kr"
kms_key_name     = "example-cmek-key"
