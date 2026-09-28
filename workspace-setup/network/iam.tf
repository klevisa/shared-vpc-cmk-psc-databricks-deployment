# -----------------------------------------------------------------------------
# STATIC Shared VPC subnet grant — the SERVICE project's Compute Engine service agent
# needs subnet access on the HOST node subnet to place cluster VMs on the Shared VPC (a
# GCP Shared VPC requirement). It needs only the service project number (no workspace),
# so it belongs to step 2.2.
#
# The Databricks WORKSPACE SA grant is NOT here — that SA doesn't exist until the
# workspace is created (step 2.4), so its network role (step 2.6) is the only other
# identity granted on the subnet.
# -----------------------------------------------------------------------------

# Least-privilege replacement for the predefined roles/compute.networkUser: the two
# permissions the agent actually needs to place VMs on the subnet. A custom role can be
# bound to a Google-managed service agent at the subnet resource level like any other
# principal (confirmed against GCP IAM docs).
#
# NOTE — omitted permission: roles/compute.networkUser also carries
# compute.subnetworks.useExternalIp, which this role deliberately drops because Databricks
# cluster VMs are private (no external IPs) in this deployment. If clusters ever need
# external IPs, cluster VM creation will fail at finalize (2.8) — add
# "compute.subnetworks.useExternalIp" here (or revert to roles/compute.networkUser). VERIFY
# clusters reach RUNNING with this narrower role.
resource "google_project_iam_custom_role" "compute_agent_subnet" {
  project     = var.vpc_network_project_id
  role_id     = "lpw.databricks.network.agent.v2"
  title       = "Databricks LPW subnet user (compute agent)"
  description = "Subnet get/use for the service project's compute agent on the Shared VPC node subnet."
  permissions = [
    "compute.subnetworks.get",
    "compute.subnetworks.use",
  ]
}

resource "google_compute_subnetwork_iam_member" "compute_agent_subnet_user" {
  project    = var.vpc_network_project_id
  region     = var.google_region
  subnetwork = google_compute_subnetwork.node_subnet.name
  role       = google_project_iam_custom_role.compute_agent_subnet.id
  member     = "serviceAccount:service-${var.google_service_project_number}@compute-system.iam.gserviceaccount.com"
}
