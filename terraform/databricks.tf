# -----------------------------------------------------------------------------
# Databricks account objects + workspace (Shared VPC).
#   - Network registration points at the HOST project's VPC/subnet + PSC endpoints.
#   - The workspace's cloud_resource_container points at the SERVICE project.
#   - CMEK registered for STORAGE + MANAGED_SERVICES.
#   - Workspace-scoped admin user is applied via the impersonation-based
#     `databricks.workspace` provider.
# -----------------------------------------------------------------------------

resource "random_string" "suffix" {
  special = false
  upper   = false
  length  = 3
}

# CMEK registration. Use case MUST be "MANAGED_SERVICES" (not "MANAGED") — the
# workspace-create call validates the key carries that exact use case.
resource "databricks_mws_customer_managed_keys" "this" {
  provider   = databricks.accounts
  account_id = var.databricks_account_id
  gcp_key_info {
    kms_key_id = local.cmek_resource_id
  }
  use_cases  = ["STORAGE", "MANAGED_SERVICES"]
  depends_on = [google_kms_crypto_key_iam_member.storage_agents]
}

# Backend (relay) + frontend (workspace) VPC endpoint registrations.
# project_id here is the HOST project, where the PSC endpoints were created.
resource "databricks_mws_vpc_endpoint" "relay" {
  provider          = databricks.accounts
  account_id        = var.databricks_account_id
  vpc_endpoint_name = "example-backend-ep-${random_string.suffix.result}"
  gcp_vpc_endpoint_info {
    project_id        = var.vpc_network_project_id
    psc_endpoint_name = var.relay_pe
    endpoint_region   = var.google_region
  }
  depends_on = [google_compute_forwarding_rule.backend_psc_ep]
}

resource "databricks_mws_vpc_endpoint" "workspace" {
  provider          = databricks.accounts
  account_id        = var.databricks_account_id
  vpc_endpoint_name = "example-frontend-ep-${random_string.suffix.result}"
  gcp_vpc_endpoint_info {
    project_id        = var.vpc_network_project_id
    psc_endpoint_name = var.workspace_pe
    endpoint_region   = var.google_region
  }
  depends_on = [google_compute_forwarding_rule.frontend_psc_ep]
}

# Private access settings. public_access_enabled is IMMUTABLE after creation.
resource "databricks_mws_private_access_settings" "pas" {
  provider                     = databricks.accounts
  private_access_settings_name = "example-pas-${random_string.suffix.result}"
  region                       = var.google_region
  public_access_enabled        = var.public_access_enabled
  private_access_level         = "ACCOUNT" # or "ENDPOINT" to restrict to specific VPC endpoints
}

# Network config: HOST project VPC + node subnet + both PSC endpoints.
resource "databricks_mws_networks" "this" {
  provider     = databricks.accounts
  account_id   = var.databricks_account_id
  network_name = "example-nw-${random_string.suffix.result}"
  gcp_network_info {
    network_project_id = var.vpc_network_project_id
    vpc_id             = google_compute_network.vpc.name
    subnet_id          = google_compute_subnetwork.node_subnet.name
    subnet_region      = var.google_region
  }
  vpc_endpoints {
    dataplane_relay = [databricks_mws_vpc_endpoint.relay.vpc_endpoint_id]
    rest_api        = [databricks_mws_vpc_endpoint.workspace.vpc_endpoint_id]
  }
}

# The workspace itself — GCE/GCS resources land in the SERVICE project.
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
  count        = var.metastore_id != "" ? 1 : 0
  provider     = databricks.accounts
  depends_on   = [databricks_mws_workspaces.this]
  workspace_id = databricks_mws_workspaces.this.workspace_id
  metastore_id = var.metastore_id
}

# -----------------------------------------------------------------------------
# Workspace admin: intentionally NOT provisioned here.
#
# The account admin that runs this template already holds workspace-admin
# implicitly on every workspace it creates, so the workspace is fully
# administered the moment it exists. No bootstrap admin is required, and the
# template never needs to reach the (private) workspace endpoint.
#
# To grant a DELEGATED workspace admin (a human who should NOT be a full account
# admin), do it the federation-clean way, entirely over the account API:
#   1. Configure SCIM in your IdP so the user/group syncs into the Databricks
#      ACCOUNT first (one-time, account-scoped, done out of band before apply).
#   2. Reference the synced identity read-only and assign it, e.g.:
#
#        data "databricks_group" "ws_admins" {
#          provider     = databricks.accounts
#          display_name = "platform-admins"   # synced from your IdP
#        }
#        resource "databricks_mws_permission_assignment" "admins" {
#          provider     = databricks.accounts
#          workspace_id = databricks_mws_workspaces.this.workspace_id
#          principal_id = data.databricks_group.ws_admins.id
#          permissions  = ["ADMIN"]
#        }
#
# Don't manage SCIM-synced users/groups as Terraform resources — reference them
# and assign. This keeps everything on accounts.gcp.databricks.com (so it works
# with public_access_enabled = false) and avoids fighting the IdP over identity.
# -----------------------------------------------------------------------------
