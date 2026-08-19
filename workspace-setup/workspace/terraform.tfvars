# ============================================================================
# step 2.4 — Data / Databricks Platform. ILLUSTRATIVE values.
# The vars under "from steps 2.2/2.3" are the outputs of the upstream configs —
# copy them in, or wire them via terraform_remote_state (see multi-team/README).
# ============================================================================
google_service_account_email = "databricks-automation@example-databricks-svc.iam.gserviceaccount.com"

databricks_account_id     = "00000000-0000-0000-0000-000000000000"
databricks_workspace_name = "example-prod-ws"
google_project_name       = "example-databricks-svc" # from step 2.1 output service_project_id
google_region             = "us-central1"
public_access_enabled     = false
metastore_id              = "11111111-2222-3333-4444-555555555555" # the region's UC metastore (see databricks-account-setup/README.md)

# ---- from step 2.3 (cmek) ----
cmek_key_id = "projects/example-databricks-svc/locations/us-central1/keyRings/example-kr/cryptoKeys/example-cmek-key"

# ---- from step 2.2 (network) ----
vpc_network_project_id = "example-shared-vpc-host"
vpc_name               = "example-vpc"
node_subnet_name       = "example-node-subnet"
workspace_pe           = "example-frontend-ep"
relay_pe               = "example-backend-ep"
