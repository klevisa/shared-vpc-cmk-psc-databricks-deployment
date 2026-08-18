# ============================================================================
# Phase 1 — Network Engineering. ILLUSTRATIVE values — replace before applying.
# ============================================================================
google_service_account_email  = "network-automation@example-shared-vpc-host.iam.gserviceaccount.com"
vpc_network_project_id        = "example-shared-vpc-host" # EXISTING HOST project
google_service_project_number = "111111111111"            # from Phase 0 output service_project_number
google_region                 = "us-central1"

vpc_name         = "example-vpc"
node_subnet_name = "example-node-subnet"
node_subnet_cidr = "10.10.0.0/24"
pe_subnet_name   = "example-psc-subnet"
pe_subnet_cidr   = "10.10.1.0/28"

workspace_pe         = "example-frontend-ep"
relay_pe             = "example-backend-ep"
workspace_pe_ip_name = "example-frontend-ip"
relay_pe_ip_name     = "example-backend-ip"

# us-central1 service attachments (see Databricks region resource docs)
workspace_service_attachment = "projects/gcp-prod-general/regions/us-central1/serviceAttachments/plproxy-psc-endpoint-all-ports"
relay_service_attachment     = "projects/prod-gcp-us-central1/regions/us-central1/serviceAttachments/ngrok-psc-endpoint"

private_zone_name = "databricks"
dns_name          = "gcp.databricks.com."
