# ============================================================================
# Phase 0 — Cloud Foundation. ILLUSTRATIVE values — replace before applying.
# Creates the SERVICE project, enables APIs on both projects, and establishes the
# Shared VPC relationship. The HOST project is assumed to already exist.
# ============================================================================
google_service_account_email = "foundation-automation@example-org-seed.iam.gserviceaccount.com"
google_region                = "us-central1"

vpc_network_project_id = "example-shared-vpc-host" # EXISTING host project

service_project_id   = "example-databricks-svc" # created here (must be globally unique)
service_project_name = "Databricks workspace service project"

# Set org_id OR folder_id (not both):
org_id          = "123456789012"
folder_id       = ""
billing_account = "XXXXXX-XXXXXX-XXXXXX"

# APIs use sensible defaults (see variables.tf); override only if needed.
