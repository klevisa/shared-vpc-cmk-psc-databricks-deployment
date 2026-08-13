# -----------------------------------------------------------------------------
# Shared VPC IAM — the grants the template legitimately manages (granting OTHER
# principals). The automation SA's own host-project permissions are NOT here: an
# identity can't meaningfully grant itself the permissions it needs to run the
# apply (it must already hold them to create the host network + set this IAM).
# Those are a PREREQUISITE the host-project owner grants before apply — see README.
#
# 1) The SERVICE project's compute identities must be allowed to place VMs on the
#    HOST project's shared subnet. Grant compute.networkUser on the node subnet to
#    the service project's Google APIs SA and Compute service agent.
#
# 2) The Databricks WORKSPACE service account (db-<workspace-id>@prod-gcp-<region>)
#    is the principal that actually launches cluster VMs and MUST hold
#    compute.networkUser on the shared subnet — this is the "several Databricks SAs
#    needed to create clusters" requirement. It only exists AFTER the workspace is
#    created, so we grant it using the workspace's own gcp_workspace_sa attribute,
#    with the dependency ordering the grant to happen post-create in the same apply.
#    Feature-dependent extras (GKE robot, serverless VPC-access agent, etc.) go
#    through var.additional_network_user_service_accounts.
# -----------------------------------------------------------------------------

# 1) Service-project compute identities -> networkUser on the shared node subnet
locals {
  service_project_network_users = [
    "serviceAccount:${var.google_service_project_number}@cloudservices.gserviceaccount.com",
    "serviceAccount:service-${var.google_service_project_number}@compute-system.iam.gserviceaccount.com",
  ]
}

resource "google_compute_subnetwork_iam_member" "shared_subnet_users" {
  for_each   = toset(local.service_project_network_users)
  project    = var.vpc_network_project_id
  region     = var.google_region
  subnetwork = google_compute_subnetwork.node_subnet.name
  role       = "roles/compute.networkUser"
  member     = each.value
}

# 2) The Databricks workspace SA (created at workspace-create) -> networkUser on the
#    shared subnet. Uses the workspace's gcp_workspace_sa attribute, so the grant
#    lands right after the workspace exists — the SA that launches cluster VMs.
resource "google_compute_subnetwork_iam_member" "workspace_sa_network_user" {
  project    = var.vpc_network_project_id
  region     = var.google_region
  subnetwork = google_compute_subnetwork.node_subnet.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${databricks_mws_workspaces.this.gcp_workspace_sa}"
}

# 2b) Any feature-dependent extra agents (GKE robot, serverless VPC access, etc.).
resource "google_compute_subnetwork_iam_member" "additional_network_users" {
  for_each   = toset(var.additional_network_user_service_accounts)
  project    = var.vpc_network_project_id
  region     = var.google_region
  subnetwork = google_compute_subnetwork.node_subnet.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${each.value}"
}
