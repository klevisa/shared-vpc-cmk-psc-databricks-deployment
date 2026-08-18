# ============================================================================
# Phase 4 — Network / Cloud IAM handback. ILLUSTRATIVE values.
# The vars under "from Phase 1/3" are upstream outputs — copy them in, or wire
# via terraform_remote_state (see multi-team/README).
# ============================================================================
google_service_account_email = "network-automation@example-shared-vpc-host.iam.gserviceaccount.com"
vpc_network_project_id       = "example-shared-vpc-host"
google_region                = "us-central1"

# ---- from Phase 1 (host-network) ----
node_subnet_name  = "example-node-subnet"
private_zone_name = "databricks"
dns_name          = "gcp.databricks.com."
frontend_pe_ip    = "10.10.1.2"
backend_pe_ip     = "10.10.1.3"

# ---- from Phase 3 (databricks-account) ----
gcp_workspace_sa = "db-1234567890123456@prod-gcp-us-central1.iam.gserviceaccount.com"
workspace_url    = "https://1234567890123456.7.gcp.databricks.com"
