# ============================================================================
# Phase 2 — Cloud Security / KMS. ILLUSTRATIVE values — replace before applying.
# Runs in parallel with Phase 1.
# ============================================================================
google_service_account_email  = "kms-automation@example-databricks-svc.iam.gserviceaccount.com"
google_project_name           = "example-databricks-svc" # SERVICE
google_service_project_number = "111111111111"           # SERVICE project number
google_region                 = "us-central1"

kms_keyring_name = "example-kr"
kms_key_name     = "example-cmek-key"
