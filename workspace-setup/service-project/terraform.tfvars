# ============================================================================
# step 2.1 — Cloud Foundation. ILLUSTRATIVE values — replace before applying.
# Creates the SERVICE project, enables APIs on both projects, and establishes the
# Shared VPC relationship. The HOST project is assumed to already exist.
# ============================================================================
google_service_account_email = "foundation-automation@example-org-seed.iam.gserviceaccount.com"
google_region                = "us-central1"

# The workspace creator SA (same SA step 2.4 impersonates) — granted the read-only
# creator role on the service project here.
databricks_account_admin_sa = "databricks-automation@example-databricks-svc.iam.gserviceaccount.com"

# Keep true through workspace creation; flip to false and re-apply in the End state
# (after step 2.8) to tear down the read-only creator role. See creator-teardown/.
create_workspace_creator_role = true

vpc_network_project_id = "example-shared-vpc-host" # EXISTING host project

service_project_id   = "example-databricks-svc" # created here (must be globally unique)
service_project_name = "Databricks workspace service project"

# Set org_id OR folder_id (not both):
org_id          = "123456789012"
folder_id       = ""
billing_account = "XXXXXX-XXXXXX-XXXXXX"

# APIs use sensible defaults (see variables.tf); override only if needed.
