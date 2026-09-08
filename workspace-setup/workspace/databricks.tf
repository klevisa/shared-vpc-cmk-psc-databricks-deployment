# -----------------------------------------------------------------------------
# Databricks account objects + workspace. Owned by Data / Databricks Platform.
# Inputs come from step 2.2 (host network / PSC endpoint names) and step 2.3 (CMEK
# key id). After apply, confirm the step-2.2 PSC endpoints have flipped to ACCEPTED.
#
# LEAST-PRIVILEGE TWO-PHASE STANDUP (see var.finalize):
#   This config is applied TWICE against the same state. The workspace creator SA
#   (databricks_account_admin_sa) holds only READ-ONLY GCP creator roles, so it can
#   never build the workspace's GCS/GCE resources itself. Instead:
#     Step 2.4 (finalize=false): create the workspace paused in PROVISIONING; this
#                 mints and returns gcp_workspace_sa without provisioning resources.
#     Steps 2.5-2.7: grant that workspace SA its operator roles (project + resource
#                 roles on the service project, network role on the subnet, CMEK).
#     Step 2.8 (finalize=true): re-apply → expected_workspace_status RUNNING → the
#                 now-authorized workspace SA provisions the buckets/VMs → RUNNING.
#   The account objects below (CMEK reg, PSC endpoint regs, PAS, network) are created
#   in phase 1 and are what flip the step-2.2 PSC endpoints PENDING → ACCEPTED.
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
# project_id = HOST project, where step 2.2 created the endpoints.
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

# The workspace — GCE/GCS resources land in the SERVICE project, but only once the
# workspace SA has its operator roles and we re-apply with finalize=true (step 2.8).
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

  # PHASE 1 (finalize=false): PROVISIONING pauses the build and returns gcp_workspace_sa
  # without creating any GCS/GCE. PHASE 2 (finalize=true): RUNNING finalizes the workspace,
  # by which point steps 2.5-2.7 have granted the SA the roles it needs to build them.
  expected_workspace_status = var.finalize ? "RUNNING" : "PROVISIONING"

  private_access_settings_id               = databricks_mws_private_access_settings.pas.private_access_settings_id
  network_id                               = databricks_mws_networks.this.network_id
  storage_customer_managed_key_id          = databricks_mws_customer_managed_keys.this.customer_managed_key_id
  managed_services_customer_managed_key_id = databricks_mws_customer_managed_keys.this.customer_managed_key_id
}

# Assign an existing Unity Catalog metastore. Only in PHASE 2 — the workspace must be
# RUNNING before it can be attached to a metastore.
resource "databricks_metastore_assignment" "this" {
  count        = var.finalize ? 1 : 0
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
