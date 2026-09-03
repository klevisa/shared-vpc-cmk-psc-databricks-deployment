# ============================================================================
# step 2.6 — Cloud Security / KMS handback. ILLUSTRATIVE values.
# The vars under "from steps 2.3/2.4" are upstream outputs — copy them in, or wire
# via terraform_remote_state (see multi-team/README).
# ============================================================================
google_service_account_email = "kms-automation@example-databricks-svc.iam.gserviceaccount.com" # same SA as step 2.3
google_project_name          = "example-databricks-svc"                                        # SERVICE project (same as step 2.3)
google_region                = "us-central1"

# ---- from step 2.3 (cmek) ----
cmek_key_id = "projects/example-databricks-svc/locations/us-central1/keyRings/example-kr/cryptoKeys/example-cmek-key"

# ---- from step 2.4 (workspace) ----
gcp_workspace_sa = "db-1234567890123456@prod-gcp-us-central1.iam.gserviceaccount.com"
