# -----------------------------------------------------------------------------
# Databricks account objects + workspace. Owned by Data / Databricks Platform.
# Inputs come from Phase 1 (host network / PSC endpoint names) and Phase 2 (CMEK
# key id). After apply, confirm the Phase-1 PSC endpoints have flipped to ACCEPTED.
# -----------------------------------------------------------------------------

resource "random_string" "suffix" {
  special = false
  upper   = false
  length  = 3
}

# CMEK registration. use_cases MUST include "MANAGED_SERVICES" (not "MANAGED").
resource "databricks_mws_customer_managed_keys" "this" {
  provider   = databricks.accounts
  account_id = var.databricks_account_id
  gcp_key_info {
    kms_key_id = var.cmek_key_id
  }
  use_cases = ["STORAGE", "MANAGED_SERVICES"]
}

# Register the backend (relay) + frontend (workspace) PSC endpoints.
# project_id = HOST project, where Phase 1 created the endpoints.
resource "databricks_mws_vpc_endpoint" "relay" {
  provider          = databricks.accounts
  account_id        = var.databricks_account_id
  vpc_endpoint_name = "${var.relay_pe}-${random_string.suffix.result}"
  gcp_vpc_endpoint_info {
    project_id        = var.vpc_network_project_id
    psc_endpoint_name = var.relay_pe
    endpoint_region   = var.google_region
  }
}

resource "databricks_mws_vpc_endpoint" "workspace" {
  provider          = databricks.accounts
  account_id        = var.databricks_account_id
  vpc_endpoint_name = "${var.workspace_pe}-${random_string.suffix.result}"
  gcp_vpc_endpoint_info {
    project_id        = var.vpc_network_project_id
    psc_endpoint_name = var.workspace_pe
    endpoint_region   = var.google_region
  }
}

# Private access settings. public_access_enabled is IMMUTABLE after creation.
resource "databricks_mws_private_access_settings" "pas" {
  provider                     = databricks.accounts
  private_access_settings_name = "${var.databricks_workspace_name}-pas-${random_string.suffix.result}"
  region                       = var.google_region
  public_access_enabled        = var.public_access_enabled
  private_access_level         = "ACCOUNT" # or "ENDPOINT" to restrict to specific VPC endpoints
}

# Network config: HOST project VPC + node subnet + both PSC endpoints.
resource "databricks_mws_networks" "this" {
  provider     = databricks.accounts
  account_id   = var.databricks_account_id
  network_name = "${var.databricks_workspace_name}-nw-${random_string.suffix.result}"
  gcp_network_info {
    network_project_id = var.vpc_network_project_id
    vpc_id             = var.vpc_name
    subnet_id          = var.node_subnet_name
    subnet_region      = var.google_region
  }
  vpc_endpoints {
    dataplane_relay = [databricks_mws_vpc_endpoint.relay.vpc_endpoint_id]
    rest_api        = [databricks_mws_vpc_endpoint.workspace.vpc_endpoint_id]
  }
}

# The workspace — GCE/GCS resources land in the SERVICE project.
resource "databricks_mws_workspaces" "this" {
  provider       = databricks.accounts
  account_id     = var.databricks_account_id
  workspace_name = var.databricks_workspace_name
  location       = var.google_region

  cloud_resource_container {
    gcp {
      project_id = var.google_project_name
    }
  }

  private_access_settings_id               = databricks_mws_private_access_settings.pas.private_access_settings_id
  network_id                               = databricks_mws_networks.this.network_id
  storage_customer_managed_key_id          = databricks_mws_customer_managed_keys.this.customer_managed_key_id
  managed_services_customer_managed_key_id = databricks_mws_customer_managed_keys.this.customer_managed_key_id
}

# Optional: assign an existing Unity Catalog metastore.
resource "databricks_metastore_assignment" "this" {
  provider     = databricks.accounts
  depends_on   = [databricks_mws_workspaces.this]
  workspace_id = databricks_mws_workspaces.this.workspace_id
  metastore_id = var.metastore_id
}

# -----------------------------------------------------------------------------
# Workspace admin: NOT provisioned here. The account admin running this apply
# already holds workspace-admin implicitly. To grant a DELEGATED admin, do it the
# federation-clean way over the account API AFTER SCIM syncs the identity:
#
#   data "databricks_group" "ws_admins" {
#     provider     = databricks.accounts
#     display_name = "platform-admins"   # synced from your IdP
#   }
#   resource "databricks_mws_permission_assignment" "admins" {
#     provider     = databricks.accounts
#     workspace_id = databricks_mws_workspaces.this.workspace_id
#     principal_id = data.databricks_group.ws_admins.id
#     permissions  = ["ADMIN"]
#   }
# -----------------------------------------------------------------------------
