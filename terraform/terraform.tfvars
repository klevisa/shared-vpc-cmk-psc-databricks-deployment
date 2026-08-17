# ============================================================================
# ILLUSTRATIVE values for a Databricks workspace on a Shared VPC.
# All names/IPs/IDs are examples — replace with real values before applying.
# ============================================================================

# ---- Identity / projects ----
google_service_account_email  = "databricks-automation@example-databricks-svc.iam.gserviceaccount.com"
google_project_name           = "example-databricks-svc"  # SERVICE project
google_service_project_number = "111111111111"            # SERVICE project number (example)
vpc_network_project_id        = "example-shared-vpc-host" # HOST project
google_region                 = "us-central1"

manage_shared_vpc_association = true

# Extra service accounts (emails, no "serviceAccount:" prefix) that need
# compute.networkUser on the shared subnet, beyond the workspace SA (auto-granted)
# and the service-project agents. Populate from what your workspace actually
# surfaces / your own investigation. Examples (uncomment as needed):
additional_network_user_service_accounts = [
  # "service-111111111111@container-engine-robot.iam.gserviceaccount.com", # GKE
  # "service-111111111111@gcp-sa-vpcaccess.iam.gserviceaccount.com",       # Serverless VPC Access
]

# ---- Databricks ----
databricks_account_id     = "00000000-0000-0000-0000-000000000000" # example account id
databricks_workspace_name = "example-prod-ws"
metastore_id              = "" # empty -> rely on auto-assignment

public_access_enabled = false # fully private (PSC-only). See README for the tradeoff.

# ---- Network (created in the HOST project) ----
vpc_name         = "example-vpc"
node_subnet_name = "example-node-subnet"
node_subnet_cidr = "10.10.0.0/24" # /24 min for cluster nodes
pe_subnet_name   = "example-psc-subnet"
pe_subnet_cidr   = "10.10.1.0/28" # /28 min for PSC endpoint IPs

# ---- PSC endpoints ----
workspace_pe         = "example-frontend-ep"
relay_pe             = "example-backend-ep"
workspace_pe_ip_name = "example-frontend-ip"
relay_pe_ip_name     = "example-backend-ip"

# us-central1 service attachments (from Databricks docs)
workspace_service_attachment = "projects/gcp-prod-general/regions/us-central1/serviceAttachments/plproxy-psc-endpoint-all-ports"
relay_service_attachment     = "projects/prod-gcp-us-central1/regions/us-central1/serviceAttachments/ngrok-psc-endpoint"

# ---- CMEK (SERVICE project) ----
kms_keyring_name = "example-kr"
kms_key_name     = "example-cmek-key"

# ---- DNS ----
private_zone_name = "databricks"
dns_name          = "gcp.databricks.com."
